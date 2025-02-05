import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    private let services = ServiceContainer.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera/Detection Tab
            LandmarkDetectionView(appState: appState)
                .environmentObject(appState)
                .tabItem {
                    Label("Discover", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // Content Feed Tab
            ContentFeedView()
                .environmentObject(appState)
                .tabItem {
                    Label("Feed", systemImage: "play.square.stack")
                }
                .tag(1)
        }
        .tint(.white) // Modern iOS style
        .task {
            do {
                try await services.auth.signInAnonymously()
            } catch {
                print("Failed to sign in: \(error)")
            }
        }
        .onChange(of: appState.shouldSwitchToFeed) { shouldSwitch in
            if shouldSwitch {
                withAnimation {
                    selectedTab = 1  // Switch to feed tab
                }
                appState.shouldSwitchToFeed = false
            }
        }
    }
} 