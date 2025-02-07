import SwiftUI
import AVKit
import FirebaseStorage

@MainActor
struct ContentItemView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var feedViewModel: ContentFeedViewModel
    let content: Content
    @StateObject private var viewModel: ContentItemViewModel
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    init(content: Content) {
        self.content = content
        _viewModel = StateObject(wrappedValue: ContentItemViewModel(
            content: content,
            services: ServiceContainer.shared
        ))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player = feedViewModel.videoManager.playerFor(url: content.videoUrl) {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                        .frame(width: geo.size.width, height: geo.size.height + safeAreaInsets.top + safeAreaInsets.bottom)
                        .offset(y: -safeAreaInsets.top)
                } else if feedViewModel.videoManager.error != nil {
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
                                
                                NavigationLink(value: AppState.NavigationDestination.placeDetail(placeId: content.placeIds[0], initialContentId: content.id)) {
                                    Text(viewModel.placeName ?? "Loading place...")
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
        .onAppear {
            Task {
                await viewModel.loadPlace()
            }
        }
    }
}

@MainActor
final class ContentItemViewModel: ObservableObject {
    @Published var placeName: String?
    @Published var isLoadingPlace = true
    private let content: Content
    private let services: ServiceContainer
    
    init(content: Content, services: ServiceContainer) {
        self.content = content
        self.services = services
    }
    
    func loadPlace() async {
        isLoadingPlace = true
        do {
            let place = try await services.firestore.fetchPlace(id: content.placeIds[0])
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
    
    func cleanup() {
        // No longer needed as video management is handled by VideoPlayerManager
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
