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
    @Published private(set) var readyPlayerUrls: Set<String> = []

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

    // This method now ONLY prepares the player, it doesn't play.
    func preparePlayer(for url: String) async {
        // If this video is already prepared, skip.
        if preloadedPlayers[url] != nil {
            print("🔄 Video \(url) already prepared. Skipping.")
            return
        }

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

            // Wait until the player item is ready before storing
            try await waitUntilPlayerItemReady(item)

            preloadedPlayers[url] = player
            readyPlayerUrls.insert(url)
            isLoading = false
            print("✅ Prepared player for URL: \(url)")

        } catch {
            self.error = error
            self.isLoading = false
            print("❌ Error preparing player for URL: \(url), Error: \(error)")
        }
    }

    // This method now ALWAYS plays (or prepares and plays).
    func play(url: String) {
        print("🎬 Starting playback for URL: \(url)")

        if let player = preloadedPlayers[url], readyPlayerUrls.contains(url) {
            currentPlayer = player
            currentlyPlayingUrl = url
            player.seek(to: .zero)
            player.play()
            print("✅ Playing from preloaded player")
        } else {
            print("⚠️ No preloaded player, preparing and playing")
            Task {
                await preparePlayer(for: url)
                // Check again after preparation
                if let player = preloadedPlayers[url], readyPlayerUrls.contains(url) {
                    currentPlayer = player
                    currentlyPlayingUrl = url
                    player.play()
                }
            }
        }
    }

    func pause() {
        currentPlayer?.pause()
        print("⏸️ Paused current playback")
    }

    /// Pause a specific URL if it's preloaded/playing
    func pause(url: String) {
        if let player = preloadedPlayers[url] {
            player.pause()
            if currentlyPlayingUrl == url {
                currentPlayer?.pause()
                currentPlayer = nil
                currentlyPlayingUrl = nil
            }
            print("⏸️ Paused playback for URL: \(url)")
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
                    await preparePlayer(for: url)
                }
            }
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

    private func cleanupDistantPreloads(currentIndex: Int) {
        // Cancel preload tasks for distant videos
        // (Implementation can be added later if needed.)
    }

    func playerFor(url: String) -> AVPlayer? {
        // First check if this is the current playing video
        if url == currentlyPlayingUrl {
            return currentPlayer
        }
        // Then check preloaded players
        return readyPlayerUrls.contains(url) ? preloadedPlayers[url] : nil
    }

    private func getDownloadURL(for gsUrl: String) async throws -> URL {
        let storageRef = Storage.storage().reference(forURL: gsUrl)
        return try await storageRef.downloadURL()
    }

    func cleanup()  {
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
        readyPlayerUrls.removeAll()
        print("Cleared video cache")
    }
}

extension VideoPlayerManager {
    nonisolated static func create() async -> VideoPlayerManager {
        await MainActor.run { VideoPlayerManager() }
    }
}