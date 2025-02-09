import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

enum NavigationDestination: Hashable {
    case placeDetail(placeId: String, initialContentId: String)
}

@MainActor
final class ContentFeedViewModel: ObservableObject {
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var selectedNeighborhood: Neighborhood? {
        didSet {
            if selectedNeighborhood != oldValue {
                Task {
                    await loadContent()
                }
            }
        }
    }
    @Published var selectedCategory: FilterCategory = .restaurant {
        didSet {
            if selectedCategory != oldValue {
                currentIndex = 0 // Reset index when category changes
            }
        }
    }
    @Published var availableCategories: [FilterCategory] = []
    @Published var contentItems: [Content] = []
    
    // When currentIndex changes we now start an async task.
    @Published var currentIndex: Int = 0 {
        didSet {
            Task {
                await updateActiveVideo()
            }
        }
    }
    @Published var isLoading = false
    @Published var places: [String: Place] = [:] // Cache of places by ID
    
    @Published private(set) var hasLoadedNeighborhoods = false
    
    let videoManager = VideoPlayerManager()
    private let services = ServiceContainer.shared

    /// This async function centralizes the video activation logic.
    func updateActiveVideo() async {
        guard !contentItems.isEmpty,
              currentIndex >= 0,
              currentIndex < contentItems.count
        else { return }
        
        let urls = contentItems.map { $0.videoUrl }
        videoManager.preloadVideos(for: urls, at: currentIndex)
        
        await videoManager.activatePlayerAsync(for: contentItems[currentIndex].videoUrl)
    }
    
    func loadUnlockedNeighborhoods() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.hasLoadedNeighborhoods = false
        }
        
        do {
            let neighborhoods = try await services.neighborhood.fetchUnlockedNeighborhoods()
            
            DispatchQueue.main.async {
                self.unlockedNeighborhoods = neighborhoods
                // Only set selectedNeighborhood if it's nil or not in the list
                if self.selectedNeighborhood == nil || 
                   !neighborhoods.contains(where: { $0.id == self.selectedNeighborhood?.id }) {
                    self.selectedNeighborhood = neighborhoods.first
                }
                self.hasLoadedNeighborhoods = true
                self.isLoading = false
            }
        } catch {
            print("Error loading neighborhoods: \(error)")
            DispatchQueue.main.async {
                self.hasLoadedNeighborhoods = true
                self.isLoading = false
            }
        }
    }
    
    private func loadAvailableCategories() async {
        guard let neighborhood = selectedNeighborhood else { return }
        
        do {
            let categories = try await services.neighborhood.fetchAvailableCategories(
                neighborhoodId: neighborhood.id!
            )
            self.availableCategories = categories
            
            if !categories.contains(selectedCategory) && !categories.isEmpty {
                selectedCategory = categories[0]
                await loadContent()
            }
        } catch {
            print("❌ Error loading available categories: \(error)")
        }
    }

    func loadContent() async {
        guard let neighborhood = selectedNeighborhood else {
            print("❌ No neighborhood selected")
            return
        }
        
        isLoading = true
        do {
            await loadAvailableCategories()
            
            print("🔄 Loading content for neighborhood: \(neighborhood.name), category: \(selectedCategory.rawValue)")
            
            let content = try await services.firestore.fetchContentByCategory(
                category: selectedCategory,
                neighborhoodId: neighborhood.id!
            )
            
            // Fetch places for all content items
            var placeMap: [String: Place] = [:]
            for item in content {
                for placeId in item.placeIds {
                    do {
                        let place = try await services.firestore.fetchPlace(id: placeId)
                        placeMap[placeId] = place
                    } catch {
                        print("Error loading place \(placeId): \(error)")
                    }
                }
            }

            self.contentItems = content
            self.places = placeMap
            print("✅ Loaded \(content.count) content items")
            
            isLoading = false
            
            // Play the first video after loading.
            if let firstContent = content.first {
                let urls = content.map { $0.videoUrl }
                // Preload videos, setting currentIndex to 0
                videoManager.preloadVideos(for: urls, at: 0)
                await videoManager.activatePlayerAsync(for: firstContent.videoUrl)
            }
        } catch {
            print("❌ Error loading content: \(error)")
            isLoading = false
        }
    }
    
    // Called when category changes
    func categorySelected(_ category: FilterCategory) {
        selectedCategory = category
        self.currentIndex = 0  // Will trigger updateActiveVideo automatically.
        Task {
            await loadContent()
        }
    }
}