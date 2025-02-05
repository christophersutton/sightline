import Foundation

// Container for all app services
class ServiceContainer {
    // Shared instance
    static let shared = ServiceContainer()
    
    // Services
    let auth: AuthServiceProtocol
    let firestore: FirestoreServiceProtocol
    
    // Private init for singleton
    private init() {
        self.auth = AuthService()
        self.firestore = FirestoreService()
    }
} 