import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class ContentFeedViewModel: ObservableObject {
    @Published var unlockedNeighborhoods: [Neighborhood] = []
    @Published var selectedNeighborhood: Neighborhood?
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0
    
    private let firestoreService = FirestoreService()
    
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
} 