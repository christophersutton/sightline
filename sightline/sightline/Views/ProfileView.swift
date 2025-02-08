import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isAnonymous {
                AuthView(viewModel: viewModel)
            } else {
                UserProfileView(viewModel: viewModel)
                    .navigationTitle("Profile")
            }
        }
        .onAppear {
            viewModel.checkAuthState()
        }
    }
}

// Combined Auth View that handles both Sign Up and Sign In
struct AuthView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var isSignIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background Image
                    Image("profile-bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    // Content
                    VStack(spacing: 24) {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Text(isSignIn ? "Sign In" : "Create an Account")
                                    .font(.custom("Baskerville-Bold", size: 28))
                                
                                if viewModel.hasPendingSavedPlaces {
                                    Text("Sign up to save your places!")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.yellow)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    Text(isSignIn ? "Welcome Back" : "Save Places, Post Content, and More")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            // Form
                            VStack(spacing: 16) {
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .foregroundColor(.black)
                                    .customTextField()
                                
                                SecureField("Password", text: $password)
                                    .textContentType(isSignIn ? .password : .newPassword)
                                    .foregroundColor(.black)
                                    .customTextField()
                                    
                                
                                if !isSignIn {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .customTextField()
                                }
                            }
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: {
                                Task {
                                    if isSignIn {
                                        await viewModel.signIn(email: email, password: password)
                                    } else {
                                        await viewModel.signUp(email: email, password: password, confirmPassword: confirmPassword)
                                    }
                                }
                            }) {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(isSignIn ? "Sign In" : "Create Account")
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(10)
                            .disabled(viewModel.isProcessing)
                            
                            // Toggle between Sign In and Sign Up
                            Button(action: {
                                withAnimation {
                                    isSignIn.toggle()
                                    viewModel.errorMessage = nil
                                }
                            }) {
                                Text(isSignIn ? "Need an account? Sign Up" : "Already have an account? Sign In")
                                    .foregroundColor(.white)
                                    .underline()
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                      
                      
                          Button(action: {
                              Task {
                                  await viewModel.resetAccount()
                              }
                          }) {
                              Text("Reset Account")
                                  .frame(maxWidth: .infinity)
                                  .padding()
                                  .background(Color.red.opacity(0.9))
                                  .foregroundColor(.white)
                                  .cornerRadius(10)
                          }
                      }
                    
                    .padding()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// User Profile View
struct UserProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background Image
                    Image("profile-bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    // Content
                    VStack(spacing: 24) {
                        // Profile Container
                        VStack(spacing: 20) {
                            // Avatar and Email
                            VStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.white)
                                
                                Text(viewModel.userEmail ?? "")
                                    .font(.headline)
                            }
                            
                            Divider()
                                .background(.white.opacity(0.5))
                            
                            // Stats or other info could go here
                            HStack(spacing: 32) {
                                StatView(title: "Places", value: "0")
                                StatView(title: "Posts", value: "0")
                                StatView(title: "Likes", value: "0")
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                        
                        // Actions Container
                        VStack(spacing: 16) {
                            // Saved Places Section
                            if !viewModel.savedPlaces.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Saved Places")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    ForEach(viewModel.savedPlaces, id: \.id) { place in
                                        VStack(alignment: .leading) {
                                            Text(place.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(place.address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        Divider()
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                Task {
                                    await viewModel.signOut()
                                }
                            }) {
                                Text("Sign Out")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                        
                    }
                    .padding()
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            Task {
                await viewModel.loadSavedPlaces()
            }
        }
    }
}

// Helper Views
struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var isAnonymous = true
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var userEmail: String?
    
    // New: maintain a list of saved Places for display
    @Published var savedPlaces: [Place] = []
    
    @Published var hasPendingSavedPlaces = false
    
    private let auth = ServiceContainer.shared.auth
    private let firestoreService = ServiceContainer.shared.firestore
    
    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            isAnonymous = user.isAnonymous
            userEmail = user.email
            
            // Check for pending saved places if anonymous
            if user.isAnonymous {
                Task {
                    await checkPendingSavedPlaces()
                }
            }
        }
        isLoading = false
    }
    
    private func checkPendingSavedPlaces() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            let placeIds = try await firestoreService.fetchSavedPlaceIds(for: userId)
            await MainActor.run {
                self.hasPendingSavedPlaces = !placeIds.isEmpty
            }
        } catch {
            print("Error checking pending saved places: \(error)")
        }
    }
    
    func signUp(email: String, password: String, confirmPassword: String) async {
        guard !isProcessing else { return }
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
        
        isProcessing = true
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
        
        isProcessing = false
    }
    
    func signOut() async {
        do {
            try await auth.signOut()
            // After signing out, Firebase will automatically sign in anonymously
            // due to our app initialization
            isAnonymous = true
            userEmail = nil
            savedPlaces.removeAll()
        } catch {
            errorMessage = "Failed to sign out"
        }
    }
    
    func signIn(email: String, password: String) async {
        guard !isProcessing else { return }
        guard !email.isEmpty else {
            errorMessage = "Please enter an email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAnonymous = false
            userEmail = result.user.email
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    func resetAccount() async {
        print("🔄 Starting account reset...")
        do {
            print("📤 Attempting to sign out current user...")
            try await auth.signOut()
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
    
    // Fetch the user's saved places from Firestore
    func loadSavedPlaces() async {
        guard let userId = Auth.auth().currentUser?.uid, !isAnonymous else { return }
        do {
            let placeIds = try await firestoreService.fetchSavedPlaceIds(for: userId)
            var fetched: [Place] = []
            for pid in placeIds {
                do {
                    let place = try await firestoreService.fetchPlace(id: pid)
                    fetched.append(place)
                } catch {
                    print("Failed to fetch place (\(pid)): \(error)")
                }
            }
            // Sort or manipulate as needed
            await MainActor.run {
                self.savedPlaces = fetched
            }
        } catch {
            print("Error fetching saved places: \(error)")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}

// Helper View Extension
extension View {
    
    func customTextField() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.white)
            .accentColor(Color.yellow)
            .tint(Color.black)
            .cornerRadius(8)
    }
}
