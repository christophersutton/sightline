// sightline/sightline/Views/ContentItemView.swift
import SwiftUI
import AVKit
import FirebaseStorage

struct ContentItemView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appStore: AppStore // Use AppStore
    let content: Content
    @State private var showingPlaceDetail = false
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @State private var isVideoReady = false

    var body: some View {
        Group {
            switch content.processingStatus {
            case .complete:
                // Normal content view
                GeometryReader { geo in
                    ZStack {
                        if let player = appStore.videoManager.playerFor(url: content.videoUrl) {
                            VideoPlayer(player: player)
                                .edgesIgnoringSafeArea(.all)
                                .frame(width: geo.size.width, height: geo.size.height + safeAreaInsets.top + safeAreaInsets.bottom)
                                .offset(y: -safeAreaInsets.top)
                                .opacity(isVideoReady ? 1.0 : 0.0)
                        } else if appStore.videoManager.error != nil { //Use app store
                            Color.black
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.yellow)
                                Text("Failed to load video")
                                    .foregroundColor(.white)
                            }
                        } else {
                            Color.black
                            ProgressView()
                                .scaleEffect(1.5)
                        }

                        // Overlay info - restructured
                        VStack {
                            Spacer()

                            // Content info overlay
                            VStack(spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(content.caption)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)

                                        // Replace NavigationLink with Button
                                        Button {
                                            showingPlaceDetail = true
                                        } label: {
                                            // Directly get placeName from appStore
                                            Text(appStore.places[content.placeIds[0]]?.name ?? "Loading place...")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(16)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 120) // Increased bottom padding to bring content up higher
                            }
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .padding(.top, -100) // Extend gradient upward
                            )
                        }
                    }
                }
            case .rejected:
                // Hide or show rejection message
                Text("Content rejected")
            case .uploading, .transcribing, .moderating, .tagging:
                // Show processing state
                Text("Processing content")
            }
        }
        // Add sheet presentation
        .sheet(isPresented: $showingPlaceDetail) {
            PlaceDetailView(placeId: content.placeIds[0], mode: .discovery)
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
                    //Pause if the video is not the currently playing video
                    if appStore.currentContentItem?.videoUrl != content.videoUrl {
                        appStore.videoManager.pause()
                    }
                }
                .onDisappear {
                    appStore.videoManager.pause()
                }
    }
}

// Add this extension to get safe area insets in SwiftUI
private extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        (UIApplication.shared.windows.first?.safeAreaInsets ?? .zero).insets
    }
}

private extension UIEdgeInsets {
    var insets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
} 
