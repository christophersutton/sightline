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
        
        self.neighborhood = neighborhoodData != nil ? Neighborhood(from: neighborhoodData!) : nil
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
    
    func detectLandmark(for image: UIImage) {
        guard !isLoading else { return }  // Prevent duplicate calls
        
        isLoading = true
        detectionResult = "Detecting..."
        detectedLandmark = nil
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            handleError("Image conversion failed.")
            return
        }
        
        let base64String = imageData.base64EncodedString()
        
        let requestData: [String: Any] = [
            "image": ["content": base64String],
            "features": [
                ["maxResults": 1, "type": "LANDMARK_DETECTION"]
            ]
        ]
        
        Task {
            do {
                let result = try await functions.httpsCallable("annotateImage").call(requestData)
                
                await MainActor.run {
                    handleDetectionResult(result.data)
                }
            } catch {
                await MainActor.run {
                    handleError(error.localizedDescription)
                }
            }
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
            saveDetectionResult(landmarkName: "None")
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
                isLoading = false
            }
            return
        }
        
        do {
            guard let userId = services.auth.userId else { return }
            
            // Use FirestoreService instead of direct Firestore access
            try await services.firestore.unlockNeighborhood(userId: userId, landmark: landmark)
            
            await MainActor.run {
                unlockStatus = "Unlocked neighborhood: \(neighborhood.name)"
                isLoading = false
                appState.lastUnlockedNeighborhoodId = neighborhood.id
                appState.shouldSwitchToFeed = true
            }
        } catch {
            await MainActor.run {
                unlockStatus = "Failed to unlock neighborhood: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func saveDetectionResult(landmarkName: String) {
        Task {
            do {
                try await services.firestore.saveDetectionResult(landmarkName: landmarkName)
            } catch {
                print("Error saving detection result: \(error.localizedDescription)")
            }
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
    @State private var showingLoadingAlert = false
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationView {
            VStack {
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
                                        viewModel.detectLandmark(for: uiImage)
                                    }
                                }
                        }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Detecting landmark...")
                        .padding()
                } else if let landmark = viewModel.detectedLandmark {
                    VStack(spacing: 8) {
                        Text("Detected: \(landmark.name)")
                            .font(.headline)
                        
                        NavigationLink(destination: LandmarkDetailView(landmark: landmark)) {
                            Text("View Details")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        if !viewModel.unlockStatus.isEmpty {
                            Text(viewModel.unlockStatus)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                } else if !viewModel.detectionResult.isEmpty {
                    Text(viewModel.detectionResult)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Landmark Detection")
        }
        .alert("Test Data Loaded", isPresented: $showingLoadingAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            viewModel.updateAppState(appState)
        }
    }
}

struct LandmarkDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        let previewAppState = AppState()
        LandmarkDetectionView()
            .environmentObject(previewAppState)
    }
}
