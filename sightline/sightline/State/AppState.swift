// sightline/sightline/State/AppState.swift
import SwiftUI

class AppState: ObservableObject {
    // Keep navigation-related properties
    @Published var shouldSwitchToFeed = false
    @Published var shouldSwitchToDiscover = false
    @Published var navigationPath = NavigationPath()

    // New property to navigate directly to Profile tab
    @Published var shouldSwitchToProfile = false

    // Keep NavigationDestination for PlaceDetail
    enum NavigationDestination: Hashable {
        case placeDetail(placeId: String, initialContentId: String)
    }
}
