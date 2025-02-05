import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ContentFeedViewModel: ObservableObject {
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var selectedNeighborhood: Neighborhood?
    @Published var selectedCategory: ContentType = .restaurant
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0 {
        didSet {
            // Handle video preloading here when we implement it
            print("Current index changed to: \(currentIndex)")
        }
    }
    @Published var isLoading = false
    
    private let services = ServiceContainer.shared
    
    func loadUnlockedNeighborhoods() async {
        guard let userId = services.auth.userId else { return }
        
        do {
            let neighborhoods = try await services.firestore.fetchUnlockedNeighborhoods(for: userId)
            await MainActor.run {
                self.unlockedNeighborhoods = neighborhoods
                if self.selectedNeighborhood == nil {
                    self.selectedNeighborhood = neighborhoods.first
                }
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
        
        await MainActor.run { isLoading = true }
        do {
            print("🔄 Loading content for neighborhood: \(neighborhood.name), category: \(selectedCategory.rawValue)")
            let content = try await services.firestore.fetchContentByCategory(
                category: selectedCategory,
                neighborhoodId: neighborhood.id
            )
            
            await MainActor.run {
                self.contentItems = content
                print("✅ Loaded \(content.count) content items")
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading content: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    // Called when category changes
    func categorySelected(_ category: ContentType) {
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