import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class ContentFeedViewModel: ObservableObject {
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var selectedNeighborhood: Neighborhood?
    @Published var selectedCategory: String = "restaurant"
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    
    private let firestoreService = FirestoreService()
    private let services = ServiceContainer.shared
    
    func loadUnlockedNeighborhoods() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            let neighborhoods = try await firestoreService.fetchUnlockedNeighborhoods(for: uid)
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
        guard let neighborhood = selectedNeighborhood else { return }
        
        isLoading = true
        do {
            let content = try await services.firestore.fetchContentByCategory(
                category: selectedCategory,
                neighborhoodId: neighborhood.id
            )
            
            await MainActor.run {
                self.contentItems = content
                self.isLoading = false
            }
        } catch {
            print("Error loading content: \(error)")
            isLoading = false
        }
    }
    
    // Called when category changes
    func categorySelected(_ category: String) {
        selectedCategory = category
        Task {
            await loadContent()
        }
    }
} 