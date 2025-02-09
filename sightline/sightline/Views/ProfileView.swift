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
                                .font(.custom("Baskerville-Bold", size: 24))
                                .foregroundColor(.black)
                                
                                if viewModel.hasPendingSavedPlaces {
                                    Text("Sign up to save your places!")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                } else {
                                    Text(isSignIn ? "Welcome Back" : "Save Places, Post Content, and More")
                                        .font(.custom("Baskerville", size: 18))
                                        .foregroundColor(.black)
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
                        .background(.thinMaterial)
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
    @State private var showProfileMenu = false
    
    var body: some View {
        ZStack {
            // Fixed Background
            Image("profile-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    profileSection
                    
                    // Unlocked Neighborhoods Section
                    unlockedNeighborhoodsSection
                    
                    // Saved Places Section
                    savedPlacesSection
                }
                .padding()
            }
        }
        .confirmationDialog("Profile Options", isPresented: $showProfileMenu) {
            Button("Add Profile Photo") {
                // Photo functionality would go here
            }
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.signOut()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var profileSection: some View {
        Button(action: { showProfileMenu = true }) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                
                Text(viewModel.userEmail ?? "")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
    
    private var unlockedNeighborhoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlocked Neighborhoods")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            if viewModel.unlockedNeighborhoods.isEmpty {
                Button(action: {
                    // TODO: Navigate to camera view
                }) {
                    HStack {
                        Text("Unlock your first neighborhood!")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.unlockedNeighborhoods, id: \.self) { neighborhood in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(neighborhood)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var savedPlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Places")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            if viewModel.savedPlaces.isEmpty {
                Text("No saved places yet")
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.savedPlaces, id: \.id) { place in
                    VStack(alignment: .leading) {
                        Text(place.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(place.address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    Divider()
                        .background(.white.opacity(0.3))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
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
    
    @Published var unlockedNeighborhoods: [String] = []
    
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
    
    func loadUnlockedNeighborhoods() async {
        // TODO: Implement fetching unlocked neighborhoods from your backend
        // For now, using placeholder data
        await MainActor.run {
            self.unlockedNeighborhoods = ["Downtown", "Midtown", "Uptown"]
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
