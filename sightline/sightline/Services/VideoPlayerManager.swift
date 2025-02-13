// sightline/sightline/Services/VideoPlayerManager.swift
import AVFoundation
import Combine
import SwiftUI
import FirebaseStorage
import AVKit
import Foundation

@MainActor
class VideoPlayerManager: ObservableObject {
    @Published private(set) var currentPlayer: AVQueuePlayer?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var preloadedPlayers: [String: AVQueuePlayer] = [:]
    private var playerLooper: AVPlayerLooper?
    private var cancellables = Set<AnyCancellable>()
    
    private let maxPreloadedPlayers = 3
    
    private var currentlyPlayingUrl: String?
    
    func activatePlayer(for url: String) async {
        print("📺 Activating player for URL: \(url)")
        
        // Always cleanup first
        await cleanup()
        
        do {
            isLoading = true
            error = nil
            currentlyPlayingUrl = url
            
            let player = try await preparePlayer(for: url)
            
            // Double check we still want this URL
            guard currentlyPlayingUrl == url else {
                print("📺 URL changed during preparation, cancelling")
                return
            }
            
            self.currentPlayer = player
            player.play()
            print("📺 Started playback for URL: \(url)")
            
        } catch {
            print("❌ Failed to activate player: \(error)")
            self.error = error
            currentlyPlayingUrl = nil
        }
        
        isLoading = false
    }
    
    func pause() {
        currentPlayer?.pause()
    }
    
    func cleanup() async {
        print("📺 Cleaning up player")
        currentPlayer?.pause()
        currentPlayer = nil
        playerLooper = nil
        currentlyPlayingUrl = nil
        preloadedPlayers.removeAll()
    }
    
    private func preparePlayer(for url: String) async throws -> AVQueuePlayer {
        print("📺 Preparing player for URL: \(url)")
        let downloadUrl = try await getDownloadURL(for: url)
        
        let asset = AVURLAsset(url: downloadUrl)
        guard try await asset.load(.isPlayable) else {
            throw VideoError.notPlayable
        }
        
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        
        try await waitUntilPlayerItemReady(item)
        return player
    }
    
    private func cleanupDistantPlayers() {
        // Keep only the most recent players up to maxPreloadedPlayers
        if preloadedPlayers.count > maxPreloadedPlayers {
            let sortedUrls = Array(preloadedPlayers.keys).sorted()
            let urlsToRemove = sortedUrls.prefix(preloadedPlayers.count - maxPreloadedPlayers)
            for url in urlsToRemove {
                preloadedPlayers.removeValue(forKey: url)
            }
        }
    }
    
    enum VideoError: Error {
        case notPlayable
    }

    // Dictionary to store preloaded players by URL
    private var preloadedVideosQueue: [String] = []
    // Maximum number of videos to cache during the session
    private let maxCacheSize = 10

    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private let preloadLimit = 2 // Number of videos to preload in each direction

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
                    do {
                        let player = try await preparePlayer(for: url)
                        preloadedPlayers[url] = player
                    } catch {
                        print("Failed to preload video for url: \(url), error: \(error)")
                    }
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
        if url == currentlyPlayingUrl {
            return currentPlayer
        }
        return preloadedPlayers[url]
    }

    private func getDownloadURL(for gsUrl: String) async throws -> URL {
        let storageRef = Storage.storage().reference(forURL: gsUrl)
        return try await storageRef.downloadURL()
    }
}

extension VideoPlayerManager {
    nonisolated static func create() async -> VideoPlayerManager {
        await MainActor.run { VideoPlayerManager() }
    }
}
