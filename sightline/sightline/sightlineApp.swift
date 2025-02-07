import SwiftUI
import FirebaseCore

@main
struct SightlineApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    init() {
        // Configure Firebase when the app starts.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    // First sign in
                    do {
                        try await ServiceContainer.shared.auth.signInAnonymously()
                        // Then preload data
                        await appViewModel.preloadAppData()
                    } catch {
                        print("Failed to initialize app: \(error)")
                    }
                }
        }
    }
}
