import SwiftUI
import AVKit

struct ContentItemView: View {
    @EnvironmentObject var appState: AppState
    let content: Content
    @StateObject private var viewModel = ContentItemViewModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                    ProgressView()
                }
                
                // Overlay info
                VStack {
                    Spacer()
                    
                    // Place pill button
                    Button(action: {
                        appState.navigationPath.append(
                            AppState.NavigationDestination.placeDetail(
                                placeId: content.placeId,
                                initialContentId: content.id
                            )
                        )
                    }) {
                        Text("View Place") // We'll style this better later
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(content.caption)
                                .font(.headline)
                            Text("\(content.likes) likes")
                                .font(.subheadline)
                        }
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            viewModel.loadVideo(from: content.videoUrl)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

class ContentItemViewModel: ObservableObject {
    @Published var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    
    func loadVideo(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Create a player item
        let item = AVPlayerItem(url: url)
        
        // Create a player and loop it
        let queuePlayer = AVQueuePlayer()
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        // Set up the player
        queuePlayer.isMuted = false // Default unmuted
        
        DispatchQueue.main.async {
            self.player = queuePlayer
            queuePlayer.play()
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        playerLooper = nil
    }
} 