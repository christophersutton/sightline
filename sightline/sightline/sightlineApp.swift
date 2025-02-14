import SwiftUI
import FirebaseCore
// Make sure SplashView is accessible
import FirebaseAuth

// sightline/sightline/sightlineApp.swift
@main
struct SightlineApp: App {
    @StateObject private var appStore = AppStore() // Use StateObject here
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var landmarkDetectionStore = LandmarkDetectionStore()
    @State private var showingSplash = true

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environmentObject(appStore)  // Inject the AppStore
                    .environmentObject(profileStore)
                    .environmentObject(landmarkDetectionStore)
                    .task {
                        // First sign in
                        do {
                            try await ServiceContainer.shared.auth.signInAnonymously()
                            // Then preload data
                            await appStore.loadUnlockedNeighborhoods()
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
                    SplashView{}
                        .transition(.opacity)
                }
            }
        }
    }
}
