import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileStore: ProfileStore // Use the ProfileStore

    var body: some View {
        ZStack {
            if profileStore.isLoading { // Use profileStore.isLoading
                ProgressView()
            } else if profileStore.isAnonymous { // Use profileStore.isAnonymous
                AuthView()
                    .environmentObject(profileStore) // Inject ProfileStore
            } else {
                UserProfileView()
                    .environmentObject(profileStore) // Inject ProfileStore
                    .navigationTitle("Profile")
            }
        }
    }
}
