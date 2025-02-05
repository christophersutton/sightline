import SwiftUI
import AVKit

struct ContentItemView: View {
    let content: Content
    @StateObject private var viewModel = ContentItemViewModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black // placeholder while loading
                    ProgressView()
                }
                
                // Video info overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(content.caption)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            Text("\(content.likes) likes")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
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