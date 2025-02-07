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
    @Published var selectedNeighborhood: Neighborhood?
    @Published var selectedCategory: FilterCategory = .restaurant
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
        // First try to load from preloaded data
        if let data = UserDefaults.standard.data(forKey: "preloadedNeighborhoods"),
           let neighborhoods = try? JSONDecoder().decode([Neighborhood].self, from: data) {
            self.unlockedNeighborhoods = neighborhoods
            if self.selectedNeighborhood == nil {
                self.selectedNeighborhood = neighborhoods.first
            }
            return
        }
        
        // Fall back to loading from Firestore
        guard let userId = services.auth.userId else { return }
        
        do {
            let neighborhoods = try await services.firestore.fetchUnlockedNeighborhoods(for: userId)
            self.unlockedNeighborhoods = neighborhoods
            if self.selectedNeighborhood == nil {
                self.selectedNeighborhood = neighborhoods.first
            }
        } catch {
            print("Error loading neighborhoods: \(error)")
        }
    }
    
    private func loadAvailableCategories() async {
        guard let neighborhood = selectedNeighborhood else { return }
        
        // First try to load from preloaded data for the first neighborhood
        if let firstNeighborhood = unlockedNeighborhoods.first,
           neighborhood.id == firstNeighborhood.id,  // Compare by ID instead
           let data = UserDefaults.standard.data(forKey: "preloadedCategories"),
           let categories = try? JSONDecoder().decode([FilterCategory].self, from: data) {
            self.availableCategories = categories
            if !categories.contains(selectedCategory) && !categories.isEmpty {
                selectedCategory = categories[0]
            }
            return
        }
        
        // Fall back to loading from Firestore
        do {
            let categories = try await services.firestore.fetchAvailableCategories(
                for: neighborhood.id!
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
            
            // Force preload current index first
            if !content.isEmpty {
                let urls = content.map { $0.videoUrl }
                videoManager.preloadVideos(for: urls, at: 0)
                await videoManager.activatePlayerAsync(for: content[0].videoUrl)
            }
            
            isLoading = false
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
