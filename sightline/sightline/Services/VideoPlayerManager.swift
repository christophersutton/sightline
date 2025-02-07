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
    
    // Dictionary to store preloaded players by URL
    private var preloadedPlayers: [String: AVQueuePlayer] = [:]
    // Queue to track the order of preloaded videos for caching purposes
    private var preloadedVideosQueue: [String] = []
    // Maximum number of videos to cache during the session
    private let maxCacheSize = 10
    
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private let preloadLimit = 2 // Number of videos to preload in each direction
    
    private var currentlyPlayingUrl: String?
    
    func prepareForDisplay(url: String) async {
        await cleanup() // Clean up any existing player first
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
            
            // Wait until the player item is ready before playing
            try await waitUntilPlayerItemReady(item)
            
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
    
    // Helper function to wait until the AVPlayerItem is ready to play
    private func waitUntilPlayerItemReady(_ item: AVPlayerItem) async throws {
        while item.status != .readyToPlay {
            if item.status == .failed {
                throw item.error ?? NSError(domain: "VideoPlayerManager", code: -1,
                                             userInfo: [NSLocalizedDescriptionKey: "Failed to load video"])
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50 ms delay
        }
    }
    
    func preloadVideos(for urls: [String], at index: Int) {
        // Cancel any existing preload tasks that are no longer needed
        cleanupDistantPreloads(currentIndex: index)
        
        // Calculate preload range (excluding the current index)
        let start = max(0, index - preloadLimit)
        let end = min(urls.count - 1, index + preloadLimit)
        
        for i in start...end where i != index {
            let url = urls[i]
            if preloadedPlayers[url] == nil && preloadTasks[url] == nil {
                preloadTasks[url] = Task {
                    await preloadVideo(url)
                }
            }
        }
    }
    
    private func preloadVideo(_ url: String) async {
        print("🔄 Preloading video: \(url)")
        do {
            let downloadUrl = try await getDownloadURL(for: url)
            let asset = AVURLAsset(url: downloadUrl)
            
            if try await asset.load(.isPlayable) {
                let item = AVPlayerItem(asset: asset)
                let player = AVQueuePlayer(playerItem: item)
                // Wait until the item is ready before storing the preloaded player
                try await waitUntilPlayerItemReady(item)
                preloadedPlayers[url] = player
                
                // Add to the caching queue and enforce maximum cache size
                preloadedVideosQueue.append(url)
                if preloadedVideosQueue.count > maxCacheSize {
                    let oldestUrl = preloadedVideosQueue.removeFirst()
                    preloadedPlayers[oldestUrl]?.pause()
                    preloadedPlayers[oldestUrl] = nil
                    print("🗑 Purged oldest video: \(oldestUrl) from cache")
                }
                
                print("✅ Successfully preloaded: \(url)")
            }
        } catch {
            print("❌ Error preloading video: \(error)")
        }
        preloadTasks[url] = nil
    }
    
    private func cleanupDistantPreloads(currentIndex: Int) {
        // Cancel preload tasks for distant videos
        // (Implementation can be added later if needed.)
    }
    
    func playerFor(url: String) -> AVPlayer? {
        if url == currentlyPlayingUrl {
            return currentPlayer
        }
        return preloadedPlayers[url]
    }
    
    /// New async activation method.
    func activatePlayerAsync(for url: String) async {
        // If this video is already active, skip reactivation.
        if currentlyPlayingUrl == url, currentPlayer != nil {
            print("🔄 Video \(url) already active. Skipping reactivation.")
            return
        }
        
        print("🎥 Activating player for URL: \(url)")
        if let player = preloadedPlayers[url] {
            print("✅ Found preloaded player")
            await cleanup()
            currentPlayer = player
            currentlyPlayingUrl = url
            await player.seek(to: .zero)
            player.play()
        } else {
            print("⚠️ No preloaded player found, loading directly")
            await prepareForDisplay(url: url)
            currentlyPlayingUrl = url
        }
    }
    
    private func getDownloadURL(for gsUrl: String) async throws -> URL {
        let storageRef = Storage.storage().reference(forURL: gsUrl)
        return try await storageRef.downloadURL()
    }
    
    func cleanup() async {
        currentPlayer?.pause()
        playerLooper = nil
        currentPlayer = nil
        currentlyPlayingUrl = nil
        error = nil
        isLoading = false
        cancellables.removeAll()
    }
    
    /// Clears the entire video cache. Call this on app close to release all cached videos.
    func clearCache() {
        preloadedPlayers.forEach { (_, player) in
            player.pause()
        }
        preloadedPlayers.removeAll()
        preloadedVideosQueue.removeAll()
        preloadTasks.removeAll()
        print("Cleared video cache")
    }
}

extension VideoPlayerManager {
    nonisolated static func create() async -> VideoPlayerManager {
        await MainActor.run { VideoPlayerManager() }
    }
}
