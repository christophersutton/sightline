import Foundation
import Combine

protocol ContentService {
    /// Fetches content items for a given neighborhood and category
    func fetchContent(neighborhoodId: String, category: FilterCategory) async throws -> [Content]
    
    /// Prefetches and caches content for a given neighborhood
    func prefetchContent(neighborhoodId: String) async
    
    /// Clears any cached content
    func clearCache() async
}

actor ContentServiceImpl: ContentService {
    private let firestore: FirestoreService
    private var cache: [String: [Content]] = [:] // neighborhoodId+category -> content
    
    init(firestore: FirestoreService) {
        self.firestore = firestore
    }
    
    func fetchContent(neighborhoodId: String, category: FilterCategory) async throws -> [Content] {
        let cacheKey = "\(neighborhoodId)_\(category.rawValue)"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            return cached
        }
        
        // Fetch from Firestore
        let content = try await firestore.fetchContentByCategory(
            category: category,
            neighborhoodId: neighborhoodId
        )
        
        // Update cache
        cache[cacheKey] = content
        
        return content
    }
    
    func prefetchContent(neighborhoodId: String) async {
        // Prefetch content for all categories
        for category in FilterCategory.allCases {
            do {
                _ = try await fetchContent(neighborhoodId: neighborhoodId, category: category)
            } catch {
                print("Error prefetching content for \(neighborhoodId), \(category): \(error)")
            }
        }
    }
    
    func clearCache() async {
        cache.removeAll()
    }
} 