import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var isPreloading = true
    private let services = ServiceContainer.shared
    
    func preloadAppData() async {
        guard let userId = services.auth.userId else { return }
        
        do {
            // Preload neighborhoods
            let neighborhoods = try await services.firestore.fetchUnlockedNeighborhoods(for: userId)
            
            // If we have neighborhoods, preload categories for the first one
            if let firstNeighborhood = neighborhoods.first {
                let categories = try await services.firestore.fetchAvailableCategories(
                    for: firstNeighborhood.id!
                )
                
                // Store preloaded data in UserDefaults for immediate access
                if let encodedNeighborhoods = try? JSONEncoder().encode(neighborhoods) {
                    UserDefaults.standard.set(encodedNeighborhoods, forKey: "preloadedNeighborhoods")
                }
                if let encodedCategories = try? JSONEncoder().encode(categories) {
                    UserDefaults.standard.set(encodedCategories, forKey: "preloadedCategories")
                }
            }
        } catch {
            print("Error preloading app data: \(error)")
        }
        
        isPreloading = false
    }
} 