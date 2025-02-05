import SwiftUI
import AVKit
import FirebaseStorage

@MainActor
struct ContentItemView: View {
    let content: Content
    @StateObject private var viewModel: ContentItemViewModel
    @EnvironmentObject private var feedViewModel: ContentFeedViewModel
    
    init(content: Content) {
        self.content = content
        self._viewModel = StateObject(
            wrappedValue: ContentItemViewModel(
                content: content,
                videoManager: VideoPlayerManager.shared // If making singleton
            )
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player = feedViewModel.videoManager.currentPlayer {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                } else if feedViewModel.videoManager.isLoading || viewModel.isLoadingPlace {
                    Color.black
                    ProgressView()
                        .scaleEffect(1.5)
                } else if feedViewModel.videoManager.error != nil {
                    Color.black
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Failed to load video")
                            .foregroundColor(.white)
                        Button("Retry") {
                            Task {
                                await feedViewModel.loadContent()
                            }
                        }
                        .foregroundColor(.blue)
                        .padding(.top)
                    }
                } else {
                    Color.black
                }
                
                // Overlay info
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(content.caption)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            NavigationLink(value: NavigationDestination.placeDetail(placeId: content.placeId, initialContentId: content.id)) {
                                Text(viewModel.placeName ?? "Loading place...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            feedViewModel.videoManager.prepareForDisplay()
            Task {
                await viewModel.loadPlace()
            }
        }
        .onDisappear {
            feedViewModel.videoManager.cleanup()
        }
    }
}

@MainActor
final class ContentItemViewModel: ObservableObject {
    @Published var placeName: String?
    @Published var isLoadingPlace = true
    private let content: Content
    private let services: ServiceContainer
    
    init(content: Content, videoManager: VideoPlayerManager) {
        self.content = content
        self.services = ServiceContainer.shared
    }
    
    func loadPlace() async {
        isLoadingPlace = true
        do {
            let place = try await services.firestore.fetchPlace(id: content.placeId)
            await MainActor.run {
                self.placeName = place.name
            }
        } catch {
            await handlePlaceLoadError(error)
        }
        isLoadingPlace = false
    }
    
    private func handlePlaceLoadError(_ error: Error) async {
        await MainActor.run {
            // Update state for error display
            print("🔴 Critical place load error: \(error.localizedDescription)")
        }
    }
}

private struct VideoPlayerManagerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: VideoPlayerManager = {
        let manager = VideoPlayerManager()
        // Ensure any UI-related setup happens here
        return manager
    }()
}

extension EnvironmentValues {
    var videoPlayerManager: VideoPlayerManager {
        get { self[VideoPlayerManagerKey.self] }
        set { self[VideoPlayerManagerKey.self] = newValue }
    }
}
