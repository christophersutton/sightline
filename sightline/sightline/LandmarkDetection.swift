import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import UIKit

// Add this struct to model the landmark data
struct LandmarkInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
    let detailedDescription: String?
    let websiteUrl: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let neighborhood: Neighborhood?
    
    init(name: String, knowledgeGraphData: [String: Any]?, locationData: [[String: Any]]?, neighborhoodData: [String: Any]?) {
        self.name = name
        self.description = knowledgeGraphData?["description"] as? String
        self.detailedDescription = (knowledgeGraphData?["detailedDescription"] as? [String: Any])?["articleBody"] as? String
        self.websiteUrl = (knowledgeGraphData?["url"] as? String)
        self.imageUrl = (knowledgeGraphData?["image"] as? [String: Any])?["contentUrl"] as? String
        
        if let firstLocation = (locationData?.first),
           let latLng = firstLocation["latLng"] as? [String: Any] {
            self.latitude = latLng["latitude"] as? Double
            self.longitude = latLng["longitude"] as? Double
        } else {
            self.latitude = nil
            self.longitude = nil
        }
        
        if let neighborhoodData = neighborhoodData {
            // Create a Neighborhood manually from the dictionary
            let id = neighborhoodData["place_id"] as? String ?? ""
            let name = neighborhoodData["name"] as? String ?? ""
            let formattedAddress = neighborhoodData["formatted_address"] as? String ?? ""
            let boundsData = neighborhoodData["bounds"] as? [String: Any] ?? [:]
            
            let neData = boundsData["northeast"] as? [String: Any] ?? [:]
            let swData = boundsData["southwest"] as? [String: Any] ?? [:]
            
            let bounds = GeoBounds(
                northeast: GeoPoint(
                    latitude: neData["lat"] as? Double ?? 0,
                    longitude: neData["lng"] as? Double ?? 0
                ),
                southwest: GeoPoint(
                    latitude: swData["lat"] as? Double ?? 0,
                    longitude: swData["lng"] as? Double ?? 0
                )
            )
            
            self.neighborhood = Neighborhood(
                id: id,
                name: name,
                formattedAddress: formattedAddress,
                bounds: bounds
            )
        } else {
            self.neighborhood = nil
        }
    }
}

class LandmarkDetectionViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var detectionResult: String = ""
    @Published var detectedLandmark: LandmarkInfo?
    @Published var unlockStatus: String = ""
    @Published var isLoading = false  // Add loading state
    
    let imageNames = ["utcapitol1", "utcapitol2", "ladybirdlake1"]
    private let services = ServiceContainer.shared  // Use services
    private lazy var functions = Functions.functions()
    private var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func detectLandmark(for image: UIImage) async {
        await MainActor.run {
            isLoading = true
            detectionResult = ""
            detectedLandmark = nil
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            await MainActor.run {
                detectionResult = "Image conversion failed."
                isLoading = false
            }
            return
        }
        
        let base64String = imageData.base64EncodedString()
        let requestData: [String: Any] = [
            "image": ["content": base64String],
            "features": [
                ["maxResults": 1, "type": "LANDMARK_DETECTION"]
            ]
        ]
        
        do {
            let result = try await functions.httpsCallable("annotateImage").call(requestData)
            if let dict = result.data as? [String: Any],
               let landmarkData = dict["landmark"] as? [String: Any] {
                
                let landmarkName = landmarkData["name"] as? String ?? "Unknown Landmark"
                let neighborhoodData = landmarkData["neighborhood"] as? [String: Any]
                
                let landmark = LandmarkInfo(
                    name: landmarkName,
                    knowledgeGraphData: nil,
                    locationData: landmarkData["locations"] as? [[String: Any]],
                    neighborhoodData: neighborhoodData
                )
                
                await MainActor.run {
                    detectedLandmark = landmark
                }
                
                // Save successful detection
                try? await saveDetectionResult(landmarkName: landmarkName)
                
                // Handle neighborhood unlock
                await handleNeighborhoodUnlock(landmark: landmark)
                
            } else {
                await MainActor.run {
                    detectionResult = "No landmarks detected."
                }
                try? await saveDetectionResult(landmarkName: "None")
            }
        } catch {
            await MainActor.run {
                detectionResult = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func handleNeighborhoodUnlock(landmark: LandmarkInfo) async {
        guard let neighborhood = landmark.neighborhood else {
            await MainActor.run {
                unlockStatus = "No neighborhood found for this landmark"
            }
            return
        }
        
        do {
            guard let userId = services.auth.userId else { return }
            try await services.firestore.unlockNeighborhood(userId: userId, landmark: landmark)
            
            await MainActor.run {
                unlockStatus = "Unlocked neighborhood: \(neighborhood.name)"
                appState.lastUnlockedNeighborhoodId = neighborhood.id
                // Also set the app to switch to the feed
                appState.shouldSwitchToFeed = true
            }
        } catch {
            await MainActor.run {
                unlockStatus = "Failed to unlock neighborhood: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveDetectionResult(landmarkName: String) async throws {
        try await services.firestore.saveDetectionResult(landmarkName: landmarkName)
    }
    
    func updateAppState(_ newAppState: AppState) {
        self.appState = newAppState
    }
}

// New view for displaying landmark details
struct LandmarkDetailView: View {
    let landmark: LandmarkInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageUrl = landmark.imageUrl,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 300)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(landmark.name)
                        .font(.title)
                        .bold()
                    
                    if let description = landmark.description {
                        Text(description)
                            .font(.subheadline)
                    }
                    
                    if let detailedDescription = landmark.detailedDescription {
                        Text(detailedDescription)
                            .font(.body)
                            .padding(.top, 8)
                    }
                    
                    if let websiteUrl = landmark.websiteUrl,
                       let url = URL(string: websiteUrl) {
                        Link("Visit Website", destination: url)
                            .padding(.top, 8)
                    }
                    
                    if let lat = landmark.latitude,
                       let lon = landmark.longitude {
                        Text("Location: \(lat), \(lon)")
                            .font(.caption)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LandmarkDetectionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LandmarkDetectionViewModel(appState: AppState())
    
    // Camera/transition states
    @State private var isCameraMode = false
    @State private var navigateToLandmark: LandmarkInfo? = nil
    @State private var showTransition: Bool = false
    @State private var shouldFlash = false
    @State private var fadeToBlack = false
    
    @Namespace private var scanningNamespace
    
    var body: some View {
        NavigationView {
            ZStack {
                if isCameraMode {
                    CameraView(
                        onFrameCaptured: { image in
                            Task {
                                await viewModel.detectLandmark(for: image)
                                if let landmark = viewModel.detectedLandmark {
                                    await animateLandmarkDetectionFlow(landmark: landmark)
                                }
                            }
                        },
                        shouldFlash: $shouldFlash
                    )
                    .ignoresSafeArea()
                    
                    if showTransition {
                        ScanningTransitionView(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    } else {
                        ScanningAnimation(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    }
                    
                    // Show any errors only, not the detected name.
                    if viewModel.detectionResult.contains("Error") {
                        VStack {
                            Spacer()
                            Text(viewModel.detectionResult)
                                .foregroundColor(.white)
                                .padding()
                                .background(.black.opacity(0.6))
                                .cornerRadius(10)
                                .padding(.bottom, 30)
                        }
                    }
                    
                    // Fade-out overlay
                    Color.black
                        .opacity(fadeToBlack ? 1.0 : 0.0)
                        .ignoresSafeArea()
                    
                    // Top bar: switch camera <-> gallery
                    VStack {
                        Picker("", selection: $isCameraMode) {
                            Text("Gallery").tag(false)
                            Text("Camera").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                        Spacer()
                    }
                    
                } else {
                    // Gallery mode
                    VStack {
                        Picker("", selection: $isCameraMode) {
                            Text("Gallery").tag(false)
                            Text("Camera").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        if let image = viewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 300)
                                .padding()
                        } else {
                            Text("Select an image to detect a landmark")
                                .padding()
                        }
                        
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(viewModel.imageNames, id: \.self) { name in
                                    Image(name)
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                        .padding(4)
                                        .onTapGesture {
                                            if let uiImage = UIImage(named: name) {
                                                viewModel.selectedImage = uiImage
                                                Task {
                                                    await viewModel.detectLandmark(for: uiImage)
                                                }
                                            }
                                        }
                                }
                            }
                        }
                        
                        // If a landmark was found in gallery mode, show link
                        if let landmark = viewModel.detectedLandmark {
                            NavigationLink(destination: LandmarkDetailView(landmark: landmark)) {
                                VStack {
                                    Text(landmark.name)
                                        .font(.headline)
                                    Text("Tap for more details")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        } else if viewModel.detectionResult.contains("Error") {
                            Text(viewModel.detectionResult)
                                .foregroundColor(.red)
                                .padding()
                        } else if viewModel.detectionResult == "No landmarks detected." {
                            Text(viewModel.detectionResult)
                                .foregroundColor(.white)
                                .padding()
                                .background(.black.opacity(0.6))
                                .cornerRadius(10)
                        }
                        
                        Spacer()
                    }
                }
                
                // Navigation link that triggers after our animations
                if let landmark = navigateToLandmark {
                    NavigationLink(
                        destination: LandmarkDetailView(landmark: landmark),
                        isActive: Binding(
                            get: { navigateToLandmark != nil },
                            set: { if !$0 { navigateToLandmark = nil } }
                        )
                    ) {
                        EmptyView()
                    }
                }
            }
            .navigationBarHidden(isCameraMode)
        }
        .onAppear {
            viewModel.updateAppState(appState)
        }
    }
    
    /// Single flow that coordinates flash, scanning lines, fade, then the detail view.
    private func animateLandmarkDetectionFlow(landmark: LandmarkInfo) async {
        // 1) Trigger camera flash
        withAnimation(.easeIn(duration: 0.1)) {
            shouldFlash = true
        }
        
        // 2) Short delay so flash is visible
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
        
        // 3) Run scanning transition
        withAnimation(.easeInOut(duration: 1.0)) {
            showTransition = true
        }
        
        // 4) Wait for scanning line to expand
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        
        // 5) Fade to black
        withAnimation(.easeIn(duration: 0.5)) {
            fadeToBlack = true
        }
        
        // 6) Wait for fade
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // 7) Navigate to detail
        navigateToLandmark = landmark
        
        // 8) Switch out of camera mode
        isCameraMode = false
        
        // 9) Reset animations
        showTransition = false
        fadeToBlack = false
        shouldFlash = false
    }
}

struct LandmarkDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        let previewAppState = AppState()
        LandmarkDetectionView()
            .environmentObject(previewAppState)
    }
}