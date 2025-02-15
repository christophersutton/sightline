import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class AppStore: Store {
    private let services = ServiceContainer.shared
    
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var availableCategories: [FilterCategory] = []
    @Published var contentItems: [Content] = []
    @Published var places: [String: Place] = [:]
    
    // We track the current selected neighborhood/category.
    @Published var selectedNeighborhood: Neighborhood? {
        didSet {
            // If neighborhood changes, we can reset the feed
            currentIndex = 0
            Task {
                await loadContent()
            }
        }
    }
    @Published var selectedCategory: FilterCategory = .restaurant {
        didSet {
            // If category changes, we can reset the feed
            currentIndex = 0
            Task {
                await loadContent()
            }
        }
    }
    
    // Track the current index in the feed
    @Published var currentIndex: Int = 0
    
    // Video manager for playing content
    let videoManager = VideoPlayerManager()
    
    // A version integer that increments whenever new content is loaded.
    @Published var feedVersion: Int = 0
    
    @Published var isLoadingContent: Bool = false
    
    func loadUnlockedNeighborhoods() async {
        print("🏪 Loading unlocked neighborhoods...")
        do {
            let neighborhoods = try await services.neighborhood.fetchUnlockedNeighborhoods()
            print("🏪 Loaded \(neighborhoods.count) neighborhoods: \(neighborhoods.map { $0.name })")
            unlockedNeighborhoods = neighborhoods
            if selectedNeighborhood == nil ||
                !neighborhoods.contains(where: { $0.id == selectedNeighborhood?.id }) {
                selectedNeighborhood = neighborhoods.first
                print("🏪 Auto-selected neighborhood: \(neighborhoods.first?.name ?? "none")")
            }
        } catch {
            print("🏪 ❌ Error loading neighborhoods: \(error)")
        }
    }
    
    func loadAvailableCategories() async {
        guard let neighborhood = selectedNeighborhood else {
            print("🏪 Cannot load categories - no neighborhood selected")
            return
        }
        
        print("🏪 Loading categories for neighborhood: \(neighborhood.name)")
        do {
            let categories = try await services.neighborhood.fetchAvailableCategories(neighborhoodId: neighborhood.id!)
//            print("🏪 Loaded \(categories.count) categories: \(categories.map { $0.name })")
            availableCategories = categories
            
            if !categories.contains(selectedCategory) && !categories.isEmpty {
                selectedCategory = categories[0]
//                print("🏪 Auto-selected category: \(categories[0].name)")
            }
        } catch {
            print("🏪 ❌ Error loading categories: \(error)")
        }
    }
    
    func loadContent() async {
        print("🏪 Starting content load...")
//        print("🏪 Current state - Neighborhood: \(selectedNeighborhood?.name ?? "none"), Category: \(selectedCategory.name)")
        
        isLoadingContent = true
        defer { isLoadingContent = false }
        videoManager.cleanup()
        
        guard let neighborhood = selectedNeighborhood else {
            print("🏪 No neighborhood selected, clearing content")
            contentItems = []
            places = [:]
            return
        }
        
        do {
            // Make sure we have categories
            await loadAvailableCategories()
            
//            print("🏪 Fetching content for neighborhood: \(neighborhood.name), category: \(selectedCategory.name)")
            
            // Fetch content for the selected neighborhood + category
            let fetchedContent = try await services.content.fetchContent(
                neighborhoodId: neighborhood.id!,
                category: selectedCategory
            )
            
            print("🏪 Fetched \(fetchedContent.count) content items")
            
            // Fill place data for each piece of content
            var placeMap: [String: Place] = [:]
            for item in fetchedContent {
                print("🏪 Content item: id=\(item.id), videoUrl=\(item.videoUrl)")
                for placeId in item.placeIds {
                    if places[placeId] == nil && placeMap[placeId] == nil {
                        if let place = try? await services.place.fetchPlace(id: placeId) {
                            placeMap[placeId] = place
                            print("🏪 Loaded place: \(place.name) (id: \(placeId))")
                        } else {
                            print("🏪 ⚠️ Failed to load place with id: \(placeId)")
                        }
                    }
                }
            }
            
            contentItems = fetchedContent
            places.merge(placeMap) { (_, new) in new }
            
            // Preload videos for the first item
            if !contentItems.isEmpty {
                let urls = contentItems.map { $0.videoUrl }
                print("🏪 Preloading \(urls.count) videos starting at index 0")
                videoManager.preloadVideos(for: urls, at: 0)
            }
            
            // Increment feedVersion so the UI reloads if data changes
            feedVersion += 1
            print("🏪 Content load complete - Feed version: \(feedVersion)")
            
        } catch {
            print("🏪 ❌ Error loading content: \(error)")
            contentItems = []
            places = [:]
        }
    }
}
