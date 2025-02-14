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
    // Changing them triggers loadContent().
    @Published var selectedNeighborhood: Neighborhood? {
        didSet {
            // Clear feed on neighborhood change
            currentIndex = 0
            Task {
                await loadContent()
            }
        }
    }
    @Published var selectedCategory: FilterCategory = .restaurant {
        didSet {
            // Clear feed on category change
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
    // We’ll pass this to the feed so that it reloads if the underlying data changes,
    // even if the item count is the same.
    @Published var feedVersion: Int = 0
    
    func loadUnlockedNeighborhoods() async {
        do {
            let neighborhoods = try await services.neighborhood.fetchUnlockedNeighborhoods()
            unlockedNeighborhoods = neighborhoods
            if selectedNeighborhood == nil ||
                !neighborhoods.contains(where: { $0.id == selectedNeighborhood?.id }) {
                selectedNeighborhood = neighborhoods.first
            }
        } catch {
            print("Error loading neighborhoods: \(error)")
        }
    }
    
    func loadAvailableCategories() async {
        guard let neighborhood = selectedNeighborhood else { return }
        do {
            let categories = try await services.neighborhood.fetchAvailableCategories(neighborhoodId: neighborhood.id!)
            availableCategories = categories
            
            if !categories.contains(selectedCategory) && !categories.isEmpty {
                selectedCategory = categories[0]
            }
        } catch {
            print("Error loading categories: \(error)")
        }
    }
    
    func loadContent() async {
        guard let neighborhood = selectedNeighborhood else {
            contentItems = []
            places = [:]
            return
        }
        do {
            // Make sure we have categories
            await loadAvailableCategories()
            
            // Fetch content for the selected neighborhood + category
            let fetchedContent = try await services.content.fetchContent(
                neighborhoodId: neighborhood.id!,
                category: selectedCategory
            )
            
            // Fill place data for each piece of content
            var placeMap: [String: Place] = [:]
            for item in fetchedContent {
                for placeId in item.placeIds {
                    if places[placeId] == nil && placeMap[placeId] == nil {
                        if let place = try? await services.place.fetchPlace(id: placeId) {
                            placeMap[placeId] = place
                        }
                    }
                }
            }
            
            contentItems = fetchedContent
            places.merge(placeMap) { (_, new) in new }
            
            // Preload videos for the first item
            if !contentItems.isEmpty {
                let urls = contentItems.map { $0.videoUrl }
                videoManager.preloadVideos(for: urls, at: 0)
            }
            
            // Increment feedVersion so that the UI can refresh even if the item count doesn’t change
            feedVersion += 1
        } catch {
            print("Error loading content: \(error)")
            contentItems = []
            places = [:]
        }
    }
}