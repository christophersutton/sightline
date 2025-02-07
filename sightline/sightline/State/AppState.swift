import SwiftUI

class AppState: ObservableObject {
    @Published var shouldSwitchToFeed = false
    @Published var shouldSwitchToDiscover = false
    @Published var lastUnlockedNeighborhoodId: String?
    @Published var navigationPath = NavigationPath()
    
    // New property to navigate directly to Profile tab
    @Published var shouldSwitchToProfile = false
    
    enum NavigationDestination: Hashable {
        case placeDetail(placeId: String, initialContentId: String)
    }
}