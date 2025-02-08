import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @StateObject private var feedViewModel = ContentFeedViewModel()
    private let services = ServiceContainer.shared
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Landmark Detection Tab
                LandmarkDetectionView()
                    .environmentObject(appState)
                    .environmentObject(feedViewModel)  // <-- Provide feedViewModel
                    .tabItem {
                        Label("Discover", systemImage: "camera.viewfinder")
                    }
                    .tag(0)
                
                // Content Feed Tab
                ContentFeedView()
                    .environmentObject(appState)
                    .environmentObject(feedViewModel)
                    .tabItem {
                        Label("Feed", systemImage: "play.square.stack")
                    }
                    .tag(1)
                
                // Profile Tab
                ProfileView()
                    .environmentObject(appState)
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(2)
            }
            .tint(.white)
            .onAppear {
                // Customize Tab Bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.black
                
                appearance.stackedLayoutAppearance.normal.iconColor = .gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
                
                appearance.stackedLayoutAppearance.selected.iconColor = .white
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
            .task {
                do {
                    try await services.auth.signInAnonymously()
                } catch {
                    print("Failed to sign in: \\(error)")
                }
            }
            // Switch to Feed when requested
            .onChange(of: appState.shouldSwitchToFeed) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        selectedTab = 1
                    }
                    appState.shouldSwitchToFeed = false
                }
            }
            // Pause video if leaving feed
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue == 1 && newValue != 1 {
                    feedViewModel.videoManager.currentPlayer?.pause()
                }
            }
            // Switch to Profile when requested
            .onChange(of: appState.shouldSwitchToProfile) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        selectedTab = 2
                    }
                    appState.shouldSwitchToProfile = false
                }
            }
        }
    }
}