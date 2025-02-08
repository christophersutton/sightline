import Foundation

protocol NeighborhoodService {
    /// Fetches unlocked neighborhoods for the current user
    func fetchUnlockedNeighborhoods() async throws -> [Neighborhood]
    
    /// Fetches available categories for a neighborhood
    func fetchAvailableCategories(neighborhoodId: String) async throws -> [FilterCategory]
    
    /// Clears the cached neighborhoods and categories
    func clearCache() async
}

actor NeighborhoodServiceImpl: NeighborhoodService {
    private let firestore: FirestoreService
    private let auth: AuthService
    private var neighborhoodsCache: [Neighborhood]?
    private var categoriesCache: [String: [FilterCategory]] = [:] // neighborhoodId -> categories
    
    init(firestore: FirestoreService, auth: AuthService) {
        self.firestore = firestore
        self.auth = auth
    }
    
    func fetchUnlockedNeighborhoods() async throws -> [Neighborhood] {
        if let cached = neighborhoodsCache {
            return cached
        }
        
        guard let userId = auth.userId else {
            throw ServiceError.notAuthenticated
        }
        
        let neighborhoods = try await firestore.fetchUnlockedNeighborhoods(for: userId)
        neighborhoodsCache = neighborhoods
        return neighborhoods
    }
    
    func fetchAvailableCategories(neighborhoodId: String) async throws -> [FilterCategory] {
        if let cached = categoriesCache[neighborhoodId] {
            return cached
        }
        
        let categories = try await firestore.fetchAvailableCategories(for: neighborhoodId)
        categoriesCache[neighborhoodId] = categories
        return categories
    }
    
    func clearCache() async {
        neighborhoodsCache = nil
        categoriesCache.removeAll()
    }
}

enum ServiceError: Error {
    case notAuthenticated
    case networkError
    case invalidData
}