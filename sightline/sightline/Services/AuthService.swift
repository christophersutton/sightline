import FirebaseAuth

protocol AuthServiceProtocol {
    // Properties
    var currentUser: User? { get }
    var userId: String? { get }
    var isAuthenticated: Bool { get }
    
    // Methods
    func signInAnonymously() async throws
    func signOut() throws
}

class AuthService: AuthServiceProtocol {
    private let auth = Auth.auth()
    
    var currentUser: User? {
        auth.currentUser
    }
    
    var userId: String? {
        currentUser?.uid
    }
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    func signInAnonymously() async throws {
        // Only sign in if not already authenticated
        guard currentUser == nil else { return }
        
        do {
            let result = try await auth.signInAnonymously()
            print("Signed in anonymously with uid: \(result.user.uid)")
        } catch {
            print("Error signing in: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signOut() throws {
        try auth.signOut()
    }
} 