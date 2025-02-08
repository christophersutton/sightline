import Foundation

// Container for all app services
class ServiceContainer {
    // Shared instance
    static let shared = ServiceContainer()
    
    // Core Services
    let auth: AuthServiceProtocol
    let firestore: FirestoreServiceProtocol
    
    // Domain Services
    private(set) lazy var content: ContentService = {
        ContentServiceImpl(firestore: firestore as! FirestoreService)
    }()
    
    private(set) lazy var neighborhood: NeighborhoodService = {
        NeighborhoodServiceImpl(firestore: firestore as! FirestoreService, auth: auth as! AuthService)
    }()
    
    private(set) lazy var place: PlaceService = {
        PlaceServiceImpl(firestore: firestore as! FirestoreService)
    }()
    
    // Private init for singleton
    private init() {
        self.auth = AuthService()
        self.firestore = FirestoreService()
    }
} 