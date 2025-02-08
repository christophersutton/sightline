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
        ContentServiceImpl(firestore: firestore)
    }()
    
    private(set) lazy var neighborhood: NeighborhoodService = {
        NeighborhoodServiceImpl(firestore: firestore, auth: auth)
    }()
    
    private(set) lazy var place: PlaceService = {
        PlaceServiceImpl(firestore: firestore)
    }()
    
    // Private init for singleton
    private init() {
        self.auth = AuthService()
        self.firestore = FirestoreService()
    }
} 