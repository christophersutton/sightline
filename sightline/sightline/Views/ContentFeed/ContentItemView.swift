import SwiftUI
import AVKit
import FirebaseStorage

struct ContentItemView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appStore: AppStore
    let content: Content
    
    @State private var showingPlaceDetail = false
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    // Add explicit observation of the video manager
    @ObservedObject private var videoManager: VideoPlayerManager
    
    init(content: Content, appStore: AppStore) {
        self.content = content
        self.videoManager = appStore.videoManager
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player = videoManager.playerFor(url: content.videoUrl) {
                    // Show the video once we have a player
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height + safeAreaInsets.top + safeAreaInsets.bottom
                        )
                        .offset(y: -safeAreaInsets.top)
                } else if videoManager.error != nil {
                    // Show an error indicator if needed
                    Color.black
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Failed to load video")
                            .foregroundColor(.white)
                    }
                } else {
                    // Show a spinner until the manager finishes preparing
                    Color.black
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }

                // Overlay content details near the bottom
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(content.caption)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            Button {
                                showingPlaceDetail = true
                            } label: {
                                Text(appStore.places[content.placeIds.first ?? ""]?.name ?? "Loading place...")
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
                    .padding(.bottom, 120)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -100)
                    )
                }
            }
        }
        .sheet(isPresented: $showingPlaceDetail) {
            if let firstPlaceId = content.placeIds.first {
                PlaceDetailView(placeId: firstPlaceId, mode: .discovery)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // When this view appears, ensure the correct video is played
        .onAppear {
            videoManager.play(url: content.videoUrl)
        }
        .onDisappear {
            videoManager.pause(url: content.videoUrl)
        }
    }
}

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