// sightline/sightline/Views/LandmarkDetection.swift
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct LandmarkDetectionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appStore: AppStore // Inject AppStore
    @EnvironmentObject var landmarkDetectionStore: LandmarkDetectionStore // Use the store

    private let detectionService = LandmarkDetectionService()

    @State private var isCameraMode = false

    // Scanning UI (Keep these)
    @State private var showTransition: Bool = false
    @State private var shouldFlash = false
    @State private var fadeToBlack = false
    @State private var showingGalleryPicker = false

    // Overlay states (Keep these)
    @State private var showUnlockedOverlay = false
    @State private var previewNeighborhood: Neighborhood? = nil
    @State private var previewLandmark: LandmarkInfo? = nil

    @Namespace private var scanningNamespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background (Keep this)
                Image("discoverbg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height + 100)
                    .clipped()

                if isCameraMode {
                    CameraView(
                        onFrameCaptured: { image in
                            Task {
                                await landmarkDetectionStore.detectLandmark(image: image, using: detectionService)
                                if let landmark = landmarkDetectionStore.detectedLandmark {
                                    await animateLandmarkDetectionFlow(landmark: landmark)
                                }
                            }
                        },
                        shouldFlash: $shouldFlash
                    )
                    .environmentObject(landmarkDetectionStore) // Inject into CameraView

                    // Close Button and Status Message (Modified for LandmarkDetectionStore)
                    VStack {
                        HStack {
                            Button {
                                isCameraMode = false
                                landmarkDetectionStore.reset() // Use store's reset
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
                    // Main Screen (Keep this, but modify button action)
                    ScrollView {
                        GeometryReader { scrollGeometry in
                            VStack {
                                Spacer(minLength: 800)
                                VStack(spacing: 16) {
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

                // Overlay (Modified for LandmarkDetectionStore and AppStore)
                if showUnlockedOverlay, let nb = previewNeighborhood, let lm = previewLandmark {
                    NeighborhoodUnlockedView(
                        neighborhood: nb,
                        landmark: lm,
                        onContinue: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showUnlockedOverlay = false
                                resetOverlayState()
                                appState.shouldSwitchToFeed = true // Navigate to feed
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
                }
            }
            .ignoresSafeArea(.container, edges: [.top])
            .sheet(isPresented: $showingGalleryPicker) { // Keep this, but modify for LandmarkDetectionStore
                NavigationView {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(landmarkDetectionStore.debugImages, id: \.self) { name in
                                Image(name)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        if let uiImage = UIImage(named: name) {
                                            Task {
                                                await landmarkDetectionStore.detectLandmark(image: uiImage, using: detectionService)
                                                if let landmark = landmarkDetectionStore.detectedLandmark {
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

    private func animateLandmarkDetectionFlow(landmark: LandmarkInfo) async {
        let startTime = Date()
        print("🕒 Starting landmark flow at: \(startTime)")
        
        // Trigger flash, haptic and success message
        withAnimation {
            shouldFlash = true
        }

        // Stop camera immediately
        isCameraMode = false
        landmarkDetectionStore.captureCompleted() // Use store's method

        // Show unlock overlay immediately with loading state
        if let neighborhood = landmark.neighborhood {
            print("🕒 About to show overlay: +\(Date().timeIntervalSince(startTime))s")
            withAnimation(.easeInOut) {
                previewNeighborhood = neighborhood
                previewLandmark = landmark
                showUnlockedOverlay = true
            }
            // Load data in background after showing UI
            Task {
                print("🕒 Starting background tasks: +\(Date().timeIntervalSince(startTime))s")
                await ServiceContainer.shared.neighborhood.clearCache()
                await appStore.loadUnlockedNeighborhoods() // Reload neighborhoods
                appStore.selectedNeighborhood = neighborhood // Set selected neighborhood
                await appStore.loadContent() // Load content for the new neighborhood
            }
        }
    }
}
