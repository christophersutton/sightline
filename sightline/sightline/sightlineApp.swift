import SwiftUI
import Firebase

@main
struct sightlineApp: App {
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
