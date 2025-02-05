import SwiftUI
import FirebaseCore

@main
struct SightlineApp: App {
    init() {
        // Configure Firebase when the app starts.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
