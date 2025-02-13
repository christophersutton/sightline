//
//  ProfileStore.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//


// sightline/sightline/Stores/ProfileStore.swift
import Combine
import FirebaseAuth
import SwiftUI

@MainActor
class ProfileStore: Store {
    private let services = ServiceContainer.shared
    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?

    @Published var user: User? // Directly store the Firebase User
    @Published var savedPlaces: [Place] = []
    @Published var unlockedNeighborhoodNames: [String] = [] // Store names, not IDs

    @Published var isAnonymous: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userEmail: String?
    @Published var hasPendingSavedPlaces: Bool = false


    init() {
        // Listen for auth state changes *when the store is created*.
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            self.user = user
            self.isAnonymous = user?.isAnonymous ?? true
            self.userEmail = user?.email

            if let user = user, user.isAnonymous {
                Task {
                    await self.checkPendingSavedPlaces()
                }
            } else if let user = user {
                 // If we have a user, load data.
                 Task {
                    await self.loadData()
                 }
            }
        }
    }

    // Make sure to remove the listener when the store is deallocated
    deinit {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    //Loads data only when authenticated
    func loadData() async {
      guard !isAnonymous else {return}
      async let savedPlacesTask = loadSavedPlaces()
      async let neighborhoodTask = loadUnlockedNeighborhoods()

      _ = await(savedPlacesTask, neighborhoodTask)
    }

    func loadSavedPlaces() async {
        guard let userId = user?.uid else { return }
        do {
            let placeIds = try await services.firestore.fetchSavedPlaceIds(for: userId)
            var fetched: [Place] = []
            try await withThrowingTaskGroup(of: Place?.self) {group in
              for pid in placeIds {
                group.addTask{
                  try await self.services.firestore.fetchPlace(id: pid)
                }
              }
              for try await place in group {
                if let place = place {
                  fetched.append(place)
                }
              }
            }
            fetched.sort{$0.name < $1.name}
            await MainActor.run {
                savedPlaces = fetched
            }
        } catch {
            print("Error fetching saved places: \(error)")
        }
    }

    func loadUnlockedNeighborhoods() async {
        guard let userId = user?.uid else { return }
        do {
            let neighborhoods = try await services.neighborhood.fetchUnlockedNeighborhoods()
            self.unlockedNeighborhoodNames = neighborhoods.map { $0.name }.sorted() // Store just names
        } catch {
            print("Error fetching unlocked neighborhoods: \(error)")
        }
    }

     func checkPendingSavedPlaces() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            let placeIds = try await services.firestore.fetchSavedPlaceIds(for: userId)
            await MainActor.run {
                self.hasPendingSavedPlaces = !placeIds.isEmpty
            }
        } catch {
            print("Error checking pending saved places: \(error)")
        }
    }
  
     func signIn(email: String, password: String) async {
        guard !isLoading else { return }
        guard !email.isEmpty else {
            errorMessage = "Please enter an email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAnonymous = false
            userEmail = result.user.email
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func removeSavedPlace(_ place: Place) async {
        guard let userId = user?.uid else { return }
        do {
            try await services.firestore.removeSavedPlace(userId: userId, placeId: place.id)
            savedPlaces.removeAll { $0.id == place.id }
        } catch {
            print("Error removing place: \(error)")
            errorMessage = "Failed to remove place."
        }
    }

     func signUp(email: String, password: String, confirmPassword: String) async {
        guard !isLoading else { return }
        guard !email.isEmpty else {
            errorMessage = "Please enter an email"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Link anonymous account with email/password
            if let user = Auth.auth().currentUser {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await user.link(with: credential)
                isAnonymous = false
                userEmail = email
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func resetAccount() async {
        print("🔄 Starting account reset...")
        do {
            print("📤 Attempting to sign out current user...")
            try services.auth.signOut()
            print("✅ Sign out successful")

            print("🗑️ Clearing UserDefaults...")
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            print("✅ UserDefaults cleared")

            // Clear any other app state/cache as needed
            print("🔄 Resetting view model state...")
            isAnonymous = true
            userEmail = nil
            errorMessage = nil
            savedPlaces.removeAll()
            print("✅ View model state reset")

            print("⏳ Waiting for Firebase to auto-create anonymous user...")
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            if let currentUser = Auth.auth().currentUser {
                print("✅ New user state: anonymous=\(currentUser.isAnonymous), email=\(currentUser.email ?? "")")
            } else {
                print("⚠️ No current user after reset")
            }
        } catch {
            print("❌ Reset failed with error: \(error.localizedDescription)")
            errorMessage = "Failed to reset account: \(error.localizedDescription)"
        }
    }

    func signOut() async {
      do {
        try services.auth.signOut()
        isAnonymous = true
        user = nil
        userEmail = nil
        savedPlaces.removeAll()
        unlockedNeighborhoodNames.removeAll()
      } catch {
        print("Failed to sign out")
      }
    }
}
