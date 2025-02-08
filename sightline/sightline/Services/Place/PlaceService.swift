import Foundation

protocol PlaceService {
    /// Fetches a place by ID
    func fetchPlace(id: String) async throws -> Place
    
    /// Prefetches places for a given array of IDs
    func prefetchPlaces(_ ids: [String]) async
}

actor PlaceServiceImpl: PlaceService {
    private let firestore: FirestoreService
    private var cache: [String: Place] = [:]
    
    init(firestore: FirestoreService) {
        self.firestore = firestore
    }
    
    func fetchPlace(id: String) async throws -> Place {
        if let cached = cache[id] {
            return cached
        }
        
        let place = try await firestore.fetchPlace(id: id)
        cache[id] = place
        return place
    }
    
    func prefetchPlaces(_ ids: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask {
                    do {
                        _ = try await self.fetchPlace(id: id)
                    } catch {
                        print("Error prefetching place \(id): \(error)")
                    }
                }
            }
        }
    }
} 