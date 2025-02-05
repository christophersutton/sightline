import SwiftUI

class AppState: ObservableObject {
    @Published var shouldSwitchToFeed = false
    @Published var lastUnlockedNeighborhoodId: String?
    @Published var navigationPath = NavigationPath()
    
    enum NavigationDestination: Hashable {
        case placeDetail(placeId: String, initialContentId: String)
    }
} 