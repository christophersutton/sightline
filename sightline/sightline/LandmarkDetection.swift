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
            let description = neighborhoodData["description"] as? String ?? ""
            let imageUrl = neighborhoodData["image_url"] as? String ?? ""
            let boundsData = neighborhoodData["bounds"] as? [String: Any] ?? [:]
            
            let neData = boundsData["northeast"] as? [String: Any] ?? [:]
            let swData = boundsData["southwest"] as? [String: Any] ?? [:]
            
            let bounds = Neighborhood.GeoBounds(
                northeast: Neighborhood.GeoBounds.Point(
                    lat: neData["lat"] as? Double ?? 0,
                    lng: neData["lng"] as? Double ?? 0
                ),
                southwest: Neighborhood.GeoBounds.Point(
                    lat: swData["lat"] as? Double ?? 0,
                    lng: swData["lng"] as? Double ?? 0
                )
            )
            
            self.neighborhood = Neighborhood(
                id: id,
                name: name,
                description: description,
                imageUrl: imageUrl,
                bounds: bounds,
                landmarks: nil  // We'll get landmarks when we fetch the full neighborhood
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
                
                // Handle neighborhood unlock
                await handleNeighborhoodUnlock(landmark: landmark)
                
            } else {
                await MainActor.run {
                    detectionResult = "No landmarks detected."
                }
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
    
    private func handleDetectionResult(_ data: Any) {
        guard let dict = data as? [String: Any] else {
            handleError("Invalid response format")
            return
        }
        
        guard let landmarkData = dict["landmark"] as? [String: Any],
              let landmarkName = landmarkData["name"] as? String else {
            detectionResult = "No landmarks detected."
            isLoading = false
            return
        }
        
        let neighborhoodData = landmarkData["neighborhood"] as? [String: Any]
        
        let landmark = LandmarkInfo(
            name: landmarkName,
            knowledgeGraphData: landmarkData["knowledgeGraph"] as? [String: Any],
            locationData: landmarkData["locations"] as? [[String: Any]],
            neighborhoodData: neighborhoodData
        )
        
        detectionResult = landmarkName
        detectedLandmark = landmark
        
        // Handle neighborhood unlock in background
        Task {
            await handleNeighborhoodUnlock(landmark: landmark)
        }
    }
    
    private func handleError(_ message: String) {
        detectionResult = "Error: \(message)"
        print("Detection error: \(message)")
        isLoading = false
    }
    
    private func handleNeighborhoodUnlock(landmark: LandmarkInfo) async {
        guard let neighborhood = landmark.neighborhood else {
            await MainActor.run {
                unlockStatus = "No neighborhood found for this landmark"
            }
            return
        }
        
        guard let neighborhoodId = neighborhood.id else {
            await MainActor.run {
                unlockStatus = "Invalid neighborhood ID"
            }
            return
        }
        
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
    @State private var showingGalleryPicker = false
    
    @Namespace private var scanningNamespace
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image - adjust position and offset
                Image("discoverbg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height + 100) // Make image taller
                    .clipped()
                
                // Status bar blur overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: geometry.safeAreaInsets.top)
                    .ignoresSafeArea()
                
                if isCameraMode {
                    // Camera View
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
                    
                    // Close Button - now respecting safe area
                    VStack {
                      HStack {
                        Button(action: {
                          isCameraMode = false
                        }) {
                          Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        }
                        .padding(.leading)
                        Spacer()
                      }
                      .padding(.top, geometry.safeAreaInsets.top)
                      Spacer()
                    }
                    
                    // Scanning animations
                    if showTransition {
                      ScanningTransitionView(namespace: scanningNamespace)
                        .ignoresSafeArea()
                    } else {
                      ScanningAnimation(namespace: scanningNamespace)
                        .ignoresSafeArea()
                    }
                    
                    // Error messages
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
                } else {
                    // Main content - center in available space
                    ScrollView {
                        GeometryReader { scrollGeometry in
                            // Center the content both vertically and horizontally
                            VStack {
                              Spacer(minLength:800)
                                
                                // Content Container
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 64))
                                        .foregroundColor(Color(.systemYellow))
                                    
                                    Text("Discover Your City")
                                        .font(.custom("Baskerville-Bold", size: 32))
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Capture landmarks to unlock neighborhood content and explore local stories")
                                        .font(.custom("Baskerville", size: 20))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Button(action: {
                                        isCameraMode = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "camera.fill")
                                                .font(.title3)
                                            Text("Open Camera")
                                                .font(.title3)
                                        }
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemYellow))
                                        .cornerRadius(12)
                                    }
                                    .padding(.top, 12)
                                }
                                .padding(24)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .shadow(radius: 8)
                                .padding()
                                
                                Spacer(minLength: 0)
                            }
                            .frame(
                                minWidth: scrollGeometry.size.width,
                                minHeight: scrollGeometry.size.height
                            )
                        }
                    }
                }
                
#if DEBUG
                // Debug Gallery Button
                VStack {
                  Spacer()
                  HStack {
                    Spacer()
                    Button(action: {
                      showingGalleryPicker = true
                    }) {
                      Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                  }
                }
#endif
            }
                
            // Navigation link for landmark detail
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
        .ignoresSafeArea(.container, edges: [.top]) // Only ignore top safe area
        .sheet(isPresented: $showingGalleryPicker) {
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(viewModel.imageNames, id: \.self) { name in
                            Image(name)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    if let uiImage = UIImage(named: name) {
                                        viewModel.selectedImage = uiImage
                                        Task {
                                            await viewModel.detectLandmark(for: uiImage)
                                        }
                                        showingGalleryPicker = false
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Debug Gallery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingGalleryPicker = false
                        }
                    }
                }
            }
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
