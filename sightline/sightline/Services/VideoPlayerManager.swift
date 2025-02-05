import AVFoundation
import Combine
import SwiftUI
import FirebaseStorage

@MainActor
final class VideoPlayerManager: ObservableObject {
    private var preloadedPlayers: [Int: AVQueuePlayer] = [:]
    private var playerLoopers: [Int: AVPlayerLooper] = [:]
    private var playerObservations: [Int: NSKeyValueObservation] = [:]
    private let maxPreloadedPlayers = 4
    private let audioTransitionDuration: Double = 0.3
    private var urlCache: [String: URL] = [:]
    private var activeFetches: Set<String> = []
    
    @Published var currentPlayer: AVQueuePlayer?
    @Published var isLoading = false
    @Published var error: Error?
    private var currentIndex: Int = 0
    
    func preloadVideos(for videoUrls: [String], at index: Int) {
        // Clear distant players first
        cleanupDistantPlayers(from: index)
        
        // Determine range to preload (2 ahead, 1 behind)
        let preloadRange = (index - 1)...(index + 2)
        
        Task {
            for i in preloadRange {
                guard i >= 0 && i < videoUrls.count else { continue }
                guard preloadedPlayers[i] == nil else { continue }
                
                let videoUrl = videoUrls[i]
                
                do {
                    let downloadUrl = try await getDownloadURL(for: videoUrl)
                    let asset = AVURLAsset(url: downloadUrl)
                    
                    // Load the asset first
                    if try await asset.load(.isPlayable) {
                        let item = AVPlayerItem(asset: asset)
                        let player = AVQueuePlayer(playerItem: item)
                        
                        // Configure player
                        player.isMuted = true
                        player.automaticallyWaitsToMinimizeStalling = true
                        
                        // Observe player status
                        let observation = player.observe(\.status, options: [.new]) { [weak self] player, _ in
                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                if player.status == .readyToPlay {
                                    // Only preroll when player is ready
                                    player.preroll(atRate: 1) { _ in }
                                    
                                    // Create looper only after player is ready
                                    if self.playerLoopers[i] == nil {
                                        let looper = AVPlayerLooper(player: player, templateItem: item)
                                        self.playerLoopers[i] = looper
                                    }
                                } else if player.status == .failed {
                                    self.error = player.error
                                }
                            }
                        }
                        
                        // Store the player and observation
                        preloadedPlayers[i] = player
                        playerObservations[i] = observation
                    }
                } catch {
                    print("❌ Error preloading video at index \(i): \(error)")
                    await MainActor.run {
                        self.error = error
                    }
                }
            }
        }
    }
    
    private func getDownloadURL(for gsUrl: String) async throws -> URL {
        // Check cache first
        if let cachedUrl = urlCache[gsUrl] {
            return cachedUrl
        }
        
        // Check if already fetching
        guard !activeFetches.contains(gsUrl) else {
            // Wait a bit and check cache again
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if let cachedUrl = urlCache[gsUrl] {
                return cachedUrl
            }
            throw NSError(domain: "VideoPlayerManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for URL"])
        }
        
        // Mark as fetching
        activeFetches.insert(gsUrl)
        defer { activeFetches.remove(gsUrl) }
        
        // Convert gs:// path to downloadable URL
        let storageRef = Storage.storage().reference(forURL: gsUrl)
        let downloadUrl = try await storageRef.downloadURL()
        
        // Cache the result
        urlCache[gsUrl] = downloadUrl
        return downloadUrl
    }
    
    func activatePlayer(at index: Int) {
        guard let newPlayer = preloadedPlayers[index] else { return }
        
        // Fade out current player
        if let oldPlayer = currentPlayer {
            fadeOutAudio(for: oldPlayer)
        }
        
        // Only activate if player is ready
        if newPlayer.status == .readyToPlay {
            // Fade in new player
            newPlayer.isMuted = false
            fadeInAudio(for: newPlayer)
            
            currentPlayer = newPlayer
            currentIndex = index
            newPlayer.play()
        }
    }
    
    private func fadeOutAudio(for player: AVQueuePlayer) {
        // Create a display link for smooth volume transition
        let startVolume = player.volume
        let startTime = CACurrentMediaTime()
        
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed >= self.audioTransitionDuration {
                player.volume = 0
                timer.invalidate()
            } else {
                let progress = Float(elapsed / self.audioTransitionDuration)
                player.volume = startVolume * (1 - progress)
            }
        }
    }
    
    private func fadeInAudio(for player: AVQueuePlayer) {
        // Create a display link for smooth volume transition
        let startTime = CACurrentMediaTime()
        
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed >= self.audioTransitionDuration {
                player.volume = 1
                timer.invalidate()
            } else {
                let progress = Float(elapsed / self.audioTransitionDuration)
                player.volume = progress
            }
        }
    }
    
    private func cleanupDistantPlayers(from currentIndex: Int) {
        let keepRange = (currentIndex - 1)...(currentIndex + 2)
        
        for (index, player) in preloadedPlayers {
            if !keepRange.contains(index) {
                player.pause()
                playerLoopers[index] = nil
                playerObservations[index]?.invalidate()
                playerObservations[index] = nil
                preloadedPlayers[index] = nil
            }
        }
    }
    
    func cleanup() {
        for (_, player) in preloadedPlayers {
            player.pause()
        }
        preloadedPlayers.removeAll()
        playerLoopers.removeAll()
        currentPlayer = nil
    }
    
    deinit {
        // Clean up all observations
        for observation in playerObservations.values {
            observation.invalidate()
        }
    }
}

extension VideoPlayerManager {
    nonisolated static func create() async -> VideoPlayerManager {
        await MainActor.run { VideoPlayerManager() }
    }
}
