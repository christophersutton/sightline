import SwiftUI
import FirebaseCore

@main
struct SightlineApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var appViewModel = AppViewModel()
    @State private var showingSplash = true
    
    init() {
        // Configure Firebase when the app starts.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(appState)
                    .task {
                        // First sign in
                        do {
                            try await ServiceContainer.shared.auth.signInAnonymously()
                            // Then preload data
                            await appViewModel.preloadAppData()
                            // Only hide splash after preloading is done
                            withAnimation {
                                showingSplash = false
                            }
                        } catch {
                            print("Failed to initialize app: \(error)")
                            // Maybe show error state in splash screen
                            showingSplash = false
                        }
                    }
                
                if showingSplash {
                    SplashView {
                        // Don't dismiss splash here anymore
                        // It will be dismissed after preloading
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
