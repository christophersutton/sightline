import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

/// Main Landmark Detection View + ViewModel,
/// referencing the new LandmarkDetectionService and LandmarkInfo model.
struct LandmarkDetectionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedViewModel: ContentFeedViewModel

    private let detectionService = LandmarkDetectionService()

    @StateObject private var viewModel: LandmarkDetectionViewModel = LandmarkDetectionViewModel()
    @State private var isCameraMode = false

    // Scanning UI
    @State private var showTransition: Bool = false
    @State private var shouldFlash = false
    @State private var fadeToBlack = false
    @State private var showingGalleryPicker = false

    // Overlay states
    @State private var showUnlockedOverlay = false
    @State private var previewNeighborhood: Neighborhood? = nil
    @State private var previewLandmark: LandmarkInfo? = nil

    @Namespace private var scanningNamespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Image("discoverbg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height + 100)
                    .clipped()

                if isCameraMode {
                    CameraView(
                        onFrameCaptured: { image in
                            Task {
                                await viewModel.detectLandmark(image: image, using: detectionService)
                                if let landmark = viewModel.detectedLandmark {
                                    await animateLandmarkDetectionFlow(landmark: landmark)
                                }
                            }
                        },
                        shouldFlash: $shouldFlash
                    )
                    .environmentObject(viewModel)

                    // Close Button and Status Message
                    VStack {
                        HStack {
                            Button {
                                isCameraMode = false
                                viewModel.reset()
                            } label: {
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

                    if showTransition {
                        ScanningTransitionView(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    } else {
                        ScanningAnimation(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    }

                    Color.black
                        .opacity(fadeToBlack ? 1.0 : 0.0)
                        .ignoresSafeArea()
                } else {
                    ScrollView {
                        GeometryReader { scrollGeometry in
                            VStack {
                                Spacer(minLength: 800)
                                VStack(spacing: 16) {
//                                    Image(systemName: "camera.viewfinder")
//                                        .font(.system(size: 64))
//                                        .foregroundColor(Color(.systemYellow))
                                    Text("Discover Your City")
                                        .font(.custom("Baskerville-Bold", size: 28))
                                        .foregroundColor(.black)
                                        .opacity(0.9)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 24)
                                    Text("Capture landmarks to unlock neighborhood content and explore local stories")
                                        .font(.custom("Baskerville", size: 20))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 24)
                                    Button {
                                        isCameraMode = true
                                    } label: {
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
                                .background(.thinMaterial)
                                .cornerRadius(16)
                                .shadow(radius: 8)
                                .padding()
                                Spacer(minLength: 0)
                            }
                            .frame(minWidth: scrollGeometry.size.width, minHeight: scrollGeometry.size.height)
                        }
                    }
                }

                if showUnlockedOverlay, let nb = previewNeighborhood, let lm = previewLandmark {
                    NeighborhoodUnlockedView(
                        neighborhood: nb,
                        landmark: lm,
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showUnlockedOverlay = false
                                resetOverlayState()
                                appState.shouldSwitchToFeed = true
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
            .ignoresSafeArea(.container, edges: [.top])
            .sheet(isPresented: $showingGalleryPicker) {
                NavigationView {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(viewModel.debugImages, id: \.self) { name in
                                Image(name)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        if let uiImage = UIImage(named: name) {
                                            Task {
                                                await viewModel.detectLandmark(image: uiImage, using: detectionService)
                                                if let landmark = viewModel.detectedLandmark {
                                                    await animateLandmarkDetectionFlow(landmark: landmark)
                                                }
                                            }
                                        }
                                        showingGalleryPicker = false
                                    }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Debug Gallery")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingGalleryPicker = false
                            }
                        }
                    }
                }
            }
            .onDisappear {
                resetOverlayState()
            }
        }
    }

    private func resetOverlayState() {
        showUnlockedOverlay = false
        previewNeighborhood = nil
        previewLandmark = nil
    }

    /// Runs the scanning animations, clears the neighborhood cache, reloads unlocked neighborhoods,
    /// and updates the feed with the new neighborhood before showing the overlay.
    private func animateLandmarkDetectionFlow(landmark: LandmarkInfo) async {
        // Trigger flash, haptic and success message
        withAnimation {
            shouldFlash = true
        }
        
        // Stop camera immediately
        isCameraMode = false
        viewModel.captureCompleted()
        
        // Show unlock overlay immediately with loading state
        if let neighborhood = landmark.neighborhood {
            withAnimation(.easeInOut) {
                previewNeighborhood = neighborhood
                previewLandmark = landmark
                showUnlockedOverlay = true
            }
            
            // Load data in background after showing UI
            Task {
                await ServiceContainer.shared.neighborhood.clearCache()
                await feedViewModel.loadUnlockedNeighborhoods()
                feedViewModel.selectedNeighborhood = neighborhood
                await feedViewModel.loadContent()
            }
        }
    }
}

/// ViewModel for controlling Landmark Detection
@MainActor
final class LandmarkDetectionViewModel: ObservableObject {
    @Published var detectedLandmark: LandmarkInfo? = nil
    @Published var errorMessage: String = ""
    @Published var debugImages: [String] = ["utcapitol1", "utcapitol2", "ladybirdlake1"]
    @Published var isCapturing = false

    private var consecutiveFailures = 0
    private let maxFailuresBeforeNotice = 3
    private var hasDetectedLandmark = false
    
    func startCapture() {
        isCapturing = true
        errorMessage = "Scanning..."
        consecutiveFailures = 0
        hasDetectedLandmark = false
    }
    
    func captureCompleted() {
        isCapturing = false
        if detectedLandmark == nil {
            errorMessage = "None detected, try finding another landmark."
        }
    }
    
    func reset() {
        isCapturing = false
        errorMessage = ""
        detectedLandmark = nil
        consecutiveFailures = 0
        hasDetectedLandmark = false
    }

    func detectLandmark(image: UIImage, using service: LandmarkDetectionService) async {
        guard !hasDetectedLandmark else { return }
        
        self.detectedLandmark = nil
        do {
            if let landmarkData = try await service.detectLandmark(in: image) {
                hasDetectedLandmark = true
                consecutiveFailures = 0
                let name = (landmarkData["name"] as? String) ?? "Unknown"
                let locations = (landmarkData["locations"] as? [[String: Any]]) ?? []
                var lat: Double? = nil
                var lon: Double? = nil
                if let firstLocation = locations.first,
                   let latLng = firstLocation["latLng"] as? [String: Any] {
                    lat = latLng["latitude"] as? Double
                    lon = latLng["longitude"] as? Double
                }
                let nbData = landmarkData["neighborhood"] as? [String: Any]
                let neighborhood = buildNeighborhood(from: nbData)
                let landmarkInfo = LandmarkInfo(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    neighborhood: neighborhood
                )
                self.detectedLandmark = landmarkInfo
                self.errorMessage = ""
                consecutiveFailures = 0
            } else {
                consecutiveFailures += 1
                if consecutiveFailures >= maxFailuresBeforeNotice && isCapturing {
                    self.errorMessage = "No landmarks detected yet... Keep scanning the area"
                }
            }
        } catch {
            consecutiveFailures += 1
            if consecutiveFailures >= maxFailuresBeforeNotice && isCapturing {
                self.errorMessage = "Having trouble detecting landmarks. Try moving closer or adjusting your angle."
            } else {
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func buildNeighborhood(from data: [String: Any]?) -> Neighborhood? {
        guard let data = data,
              let placeId = data["place_id"] as? String,
              let nbName = data["name"] as? String,
              let geometry = data["bounds"] as? [String: Any],
              let ne = geometry["northeast"] as? [String: Any],
              let sw = geometry["southwest"] as? [String: Any] else {
            return nil
        }
        let bounds = Neighborhood.GeoBounds(
            northeast: Neighborhood.GeoBounds.Point(
                lat: ne["lat"] as? Double ?? 0,
                lng: ne["lng"] as? Double ?? 0
            ),
            southwest: Neighborhood.GeoBounds.Point(
                lat: sw["lat"] as? Double ?? 0,
                lng: sw["lng"] as? Double ?? 0
            )
        )
        return Neighborhood(
            id: placeId,
            name: nbName,
            description: nil,
            imageUrl: nil,
            bounds: bounds,
            landmarks: nil
        )
    }
}
