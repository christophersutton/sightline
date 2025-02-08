import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

/// Main Landmark Detection View + ViewModel,
/// referencing the new LandmarkDetectionService and LandmarkInfo model.
struct LandmarkDetectionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedViewModel: ContentFeedViewModel  // <-- Add feedViewModel

    private let detectionService = LandmarkDetectionService()

    @StateObject private var viewModel: LandmarkDetectionViewModel = LandmarkDetectionViewModel()
    @State private var isCameraMode = false
    @State private var navigateToLandmark: LandmarkInfo? = nil

    // Scanning UI
    @State private var showTransition: Bool = false
    @State private var shouldFlash = false
    @State private var fadeToBlack = false
    @State private var showingGalleryPicker = false

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

                // If we're in camera mode
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
                                viewModel.reset() // Reset ViewModel state
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
                        .padding(.top, geometry.safeAreaInsets.top + 40)
                        Spacer()

                        // Status/Error Message
                        if !viewModel.errorMessage.isEmpty {
                            Text(viewModel.errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(.black.opacity(0.6))
                                .cornerRadius(10)
                                .padding(.bottom, geometry.size.height * 0.3) // Move up
                        }
                    }

                    // Scanning animations
                    if showTransition {
                        ScanningTransitionView(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    } else {
                        ScanningAnimation(namespace: scanningNamespace)
                            .ignoresSafeArea()
                    }

                    // Fade-out overlay
                    Color.black
                        .opacity(fadeToBlack ? 1.0 : 0.0)
                        .ignoresSafeArea()
                } else {
                    // Normal "Discover" screen
                    ScrollView {
                        GeometryReader { scrollGeometry in
                            VStack {
                                Spacer(minLength: 800)

                                VStack(spacing: 16) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 64))
                                        .foregroundColor(Color(.systemYellow))

                                    Text("Discover Your City")
                                        .font(.custom("Baskerville-Bold", size: 32))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 24)

                                    Text("Capture landmarks to unlock neighborhood content and explore local stories")
                                        .font(.custom("Baskerville", size: 20))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
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
                // Debug Gallery button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingGalleryPicker = true
                        } label: {
                            Image(systemName: "photo.stack")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 160)
                    }
                }
                #endif
            }
            .ignoresSafeArea(.container, edges: [.top])
            // LandmarkDetail Navigation
            .navigationDestination(isPresented: Binding(
                get: { navigateToLandmark != nil },
                set: { if !$0 { navigateToLandmark = nil } }
            )) {
                if let landmark = navigateToLandmark {
                    LandmarkDetailView(landmark: landmark)
                }
            }
            // Debug gallery
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
        }
    }

    /// Runs the fancy scanning animations, then transitions to feed or detail, updating unlocked neighborhoods
    private func animateLandmarkDetectionFlow(landmark: LandmarkInfo) async {
        // 1) Flash
        withAnimation(.easeIn(duration: 0.1)) {
            shouldFlash = true
        }
        // 2) Wait a moment
        try? await Task.sleep(nanoseconds: 150_000_000)

        // 3) Scanning transition
        withAnimation(.easeInOut(duration: 1.0)) {
            showTransition = true
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // 4) Fade to black
        withAnimation(.easeIn(duration: 0.5)) {
            fadeToBlack = true
        }
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Reload neighborhoods and content
        await feedViewModel.loadUnlockedNeighborhoods()
        await feedViewModel.loadContent()

        // 5) Show Landmark Detail
        navigateToLandmark = landmark

        // Turn off camera mode
        isCameraMode = false

        // Reset animations
        showTransition = false
        fadeToBlack = false
        shouldFlash = false
        
        viewModel.captureCompleted() // Signal capture completion
    }
}

/// ViewModel for controlling Landmark Detection
@MainActor
final class LandmarkDetectionViewModel: ObservableObject {
    @Published var detectedLandmark: LandmarkInfo? = nil
    @Published var errorMessage: String = ""
    @Published var debugImages: [String] = ["utcapitol1", "utcapitol2", "ladybirdlake1"]
    @Published var isCapturing = false // Track capture state

    private var consecutiveFailures = 0
    private let maxFailuresBeforeNotice = 3
    
    func startCapture() {
        isCapturing = true
        errorMessage = "Scanning..."
        consecutiveFailures = 0
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
    }

    func detectLandmark(image: UIImage, using service: LandmarkDetectionService) async {
        // Don't reset errorMessage here
        self.detectedLandmark = nil

        do {
            if let landmarkData = try await service.detectLandmark(in: image) {
                // Reset failures counter on success
                consecutiveFailures = 0
                
                // Extract the top-level landmark name
                let name = (landmarkData["name"] as? String) ?? "Unknown"
                let locations = (landmarkData["locations"] as? [[String: Any]]) ?? []
                var lat: Double? = nil
                var lon: Double? = nil
                if let firstLocation = locations.first,
                   let latLng = firstLocation["latLng"] as? [String: Any] {
                    lat = latLng["latitude"] as? Double
                    lon = latLng["longitude"] as? Double
                }

                // Possibly there's a neighborhood dictionary
                let nbData = landmarkData["neighborhood"] as? [String: Any]
                let neighborhood = buildNeighborhood(from: nbData)

                let landmarkInfo = LandmarkInfo(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    neighborhood: neighborhood
                )
                self.detectedLandmark = landmarkInfo
                self.errorMessage = "" // Clear message on success
                consecutiveFailures = 0 // Reset on success
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