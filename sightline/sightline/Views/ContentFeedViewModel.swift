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
    @Published var selectedCategory: ContentType = .restaurant
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0 {
        didSet {
            if currentIndex != oldValue {
                videoManager.activatePlayer(at: currentIndex)
            }
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
    
    // Called when tab becomes active
    func loadContent() async {
        guard let neighborhood = selectedNeighborhood else {
            print("❌ No neighborhood selected")
            return
        }
        
        isLoading = true
        do {
            print("🔄 Loading content for neighborhood: \(neighborhood.name), category: \(selectedCategory.rawValue)")
            let content = try await services.firestore.fetchContentByCategory(
                category: selectedCategory,
                neighborhoodId: neighborhood.id
            )
            
            // Fetch places for all content items
            var placeMap: [String: Place] = [:]
            for item in content {
                do {
                    let place = try await services.firestore.fetchPlace(id: item.placeId)
                    placeMap[item.placeId] = place
                } catch {
                    print("Error loading place \(item.placeId): \(error)")
                }
            }
            
            self.contentItems = content
            self.places = placeMap
            print("✅ Loaded \(content.count) content items")
            
            // Reset to first item and preload videos
            if !content.isEmpty {
                self.currentIndex = 0
                let urls = content.map { $0.videoUrl }
                videoManager.preloadVideos(for: urls, at: currentIndex)
                videoManager.activatePlayer(at: currentIndex)
            }
            
            isLoading = false
        } catch {
            print("❌ Error loading content: \(error)")
            isLoading = false
        }
    }
    
    // Called when category changes
    func categorySelected(_ category: ContentType) {
        selectedCategory = category
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
            try await services.firestore.unlockTestNeighborhood(for: userId)
            print("✅ Test neighborhood unlocked")
            
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