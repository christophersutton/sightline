import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @StateObject private var feedViewModel = ContentFeedViewModel()
    private let services = ServiceContainer.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Camera/Detection Tab
            LandmarkDetectionView()
                .environmentObject(appState)
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
        .tint(.white)  // Makes the selected tab white
        .onAppear {
            // Style the unselected tabs to be more visible
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.black
            
            // Style the unselected items
            appearance.stackedLayoutAppearance.normal.iconColor = .gray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            
            // Style the selected items
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
                print("Failed to sign in: \(error)")
            }
        }
        .onChange(of: appState.shouldSwitchToFeed) { oldValue, newValue in
            if newValue {
                withAnimation {
                    selectedTab = 1
                }
                appState.shouldSwitchToFeed = false
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue != 1 {
                // Instead of cleaning up state, just pause the current video.
                feedViewModel.videoManager.currentPlayer?.pause()
            }
        }
    }
}