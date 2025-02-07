import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

enum NavigationDestination: Hashable {
    case placeDetail(placeId: String, initialContentId: String)
}

@MainActor
class ContentFeedViewModel: ObservableObject {
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var selectedNeighborhood: Neighborhood?
    @Published var selectedCategory: FilterCategory = .restaurant
    @Published var availableCategories: [FilterCategory] = []
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0 {
        didSet {
            // Handle video preloading here when we implement it
            print("Current index changed to: \(currentIndex)")
        }
    }
    @Published var isLoading = false
    @Published var places: [String: Place] = [:] // Cache of places by ID
    
    let videoManager = VideoPlayerManager()
    private let services = ServiceContainer.shared

    func loadUnlockedNeighborhoods() async {
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
              for placeId in item.placeIds {  // Iterate through the array of placeIds
                  do {
                      let place = try await services.firestore.fetchPlace(id: placeId)
                      placeMap[placeId] = place
                  } catch {
                      print("Error loading place \(placeId): \(error)")
                  }
              }
          }

            self.contentItems = content
            
            self.contentItems = content
            self.places = placeMap
            print("✅ Loaded \(content.count) content items")
            
            // Reset to first item and preload videos
            if !content.isEmpty {
                self.currentIndex = 0
                let urls = content.map { $0.videoUrl }
                videoManager.preloadVideos(for: urls, at: currentIndex)
                videoManager.activatePlayer(at: content[0].videoUrl)
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
        currentIndex = 0  // Reset index when category changes
        Task {
            await loadContent()
        }
    }
    
    func loadTestData() async throws {
        isLoading = true
        do {
            print("🔄 Starting test data load...")
            
            // First populate test data
            try await services.firestore.populateTestData()
            print("✅ Test data populated")
            
            // Then unlock a test neighborhood
            guard let userId = services.auth.userId else {
                print("❌ No user ID found")
                return
            }
            
            // Load the unlocked neighborhoods
            await loadUnlockedNeighborhoods()
            print("✅ Neighborhoods loaded: \(unlockedNeighborhoods.count)")
            
            // Finally load content
            await loadContent()
            print("✅ Content loaded: \(contentItems.count) items")
        } catch {
            print("❌ Error loading test data: \(error)")
        }
        isLoading = false
    }
}
