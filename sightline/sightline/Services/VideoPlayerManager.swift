import AVFoundation
import Combine
import SwiftUI
import FirebaseStorage
import AVKit
import Foundation

@MainActor
final class VideoPlayerManager: ObservableObject {
    @Published private(set) var currentPlayer: AVPlayer?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var playerLooper: AVPlayerLooper?
    private var cancellables = Set<AnyCancellable>()
    private var preloadedPlayers: [String: AVQueuePlayer] = [:]
    
    func prepareForDisplay(url: String) async {
        cleanup() // Clean up existing player first
        isLoading = true
        error = nil
        
        do {
            let downloadUrl = try await getDownloadURL(for: url)
            let asset = AVURLAsset(url: downloadUrl)
            
            guard try await asset.load(.isPlayable) else {
                throw NSError(domain: "VideoPlayerManager", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Video is not playable"])
            }
            
            let item = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: item)
            playerLooper = AVPlayerLooper(player: player, templateItem: item)
            
            player.publisher(for: \.status)
                .sink { [weak self] status in
                    if status == .failed {
                        self?.error = player.error
                    }
                }
                .store(in: &cancellables)
            
            self.currentPlayer = player
            self.isLoading = false
            player.play()
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
    
    func preloadVideos(for urls: [String], at index: Int) {
        // Preload the next few videos
        let preloadRange = max(0, index-1)...min(urls.count-1, index+2)
        
        for i in preloadRange {
            let url = urls[i]
            if preloadedPlayers[url] == nil {
                Task {
                    do {
                        let downloadUrl = try await getDownloadURL(for: url)
                        let asset = AVURLAsset(url: downloadUrl)
                        if try await asset.load(.isPlayable) {
                            let item = AVPlayerItem(asset: asset)
                            let player = AVQueuePlayer(playerItem: item)
                            preloadedPlayers[url] = player
                        }
                    } catch {
                        print("Error preloading video: \(error)")
                    }
                }
            }
        }
    }
    
    func activatePlayer(at url: String) {
        if let player = preloadedPlayers[url] {
            cleanup()
            currentPlayer = player
            player.play()
        }
    }
    
    private func getDownloadURL(for gsUrl: String) async throws -> URL {
        let storageRef = Storage.storage().reference(forURL: gsUrl)
        return try await storageRef.downloadURL()
    }
    
    func cleanup() {
        currentPlayer?.pause()
        playerLooper = nil
        currentPlayer = nil
        error = nil
        isLoading = false
        cancellables.removeAll()
    }
}

extension VideoPlayerManager {
    nonisolated static func create() async -> VideoPlayerManager {
        await MainActor.run { VideoPlayerManager() }
    }
}
