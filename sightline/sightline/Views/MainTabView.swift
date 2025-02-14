// sightline/sightline/Views/MainTabView.swift
import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    // Inject the stores
    @EnvironmentObject var appStore: AppStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var landmarkDetectionStore: LandmarkDetectionStore

    private let services = ServiceContainer.shared

    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            TabView(selection: $selectedTab) {
                // Landmark Detection Tab
                LandmarkDetectionView()
                    .environmentObject(appState)
                    .environmentObject(landmarkDetectionStore) // Inject LandmarkDetectionStore
                    .tabItem {
                        Label("Discover", systemImage: "camera.viewfinder")
                    }
                    .tag(0)

                // Content Feed Tab
                ContentFeedView()
                    .environmentObject(appState)
                    .environmentObject(appStore)  // Inject AppStore
                    .tabItem {
                        Label("Feed", systemImage: "play.square.stack")
                    }
                    .tag(1)


                // Profile Tab
                ProfileView()
                    .environmentObject(appState)
                    .environmentObject(profileStore) // Inject ProfileStore
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .tag(2)
            }
            .tint(.white)
            .onAppear {
                // Customize Tab Bar appearance (remains unchanged)
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
                // Sign in anonymously *before* loading any data.
                do {
                    try await services.auth.signInAnonymously()
                } catch {
                    print("Failed to sign in: \(error)")
                }
            }
            // Switch to Feed when requested (remains, but uses appStore)
            .onChange(of: appState.shouldSwitchToFeed) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        selectedTab = 1
                    }
                    appState.shouldSwitchToFeed = false // Reset the flag
                }
            }
            // Switch to Profile when requested
            .onChange(of: appState.shouldSwitchToProfile) { oldValue, newValue in
                if newValue {
                    withAnimation {
                        selectedTab = 2
                    }
                    appState.shouldSwitchToProfile = false // Reset flag
                }
            }

            // Pause video if leaving feed (remains, but uses appStore)
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue == 1 && newValue != 1 {
                    appStore.videoManager.pause() // Use the new pause method
                }
            }

            // Add this navigationDestination modifier (remains unchanged)
            .navigationDestination(for: AppState.NavigationDestination.self) { destination in
                switch destination {
                case .placeDetail(let placeId, let initialContentId):
                    PlaceDetailView(placeId: placeId)
                }
            }
        }
    }
}
