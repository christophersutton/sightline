import SwiftUI

class AppState: ObservableObject {
    @Published var shouldSwitchToFeed = false
    @Published var lastUnlockedNeighborhoodId: String?
} 