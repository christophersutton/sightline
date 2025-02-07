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
                                
                                Text(isSignIn ? "Welcome Back" : "Save Places, Post Content, and More")
                                    .font(.custom("Baskerville", size: 18))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
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
                            .background(Color.accentColor)
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
    
    private let auth = ServiceContainer.shared.auth
    
    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            isAnonymous = user.isAnonymous
            userEmail = user.email
        }
        isLoading = false
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
            // Use proper Firebase Auth type
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAnonymous = false
            userEmail = result.user.email
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    func resetAccount() async {
        do {
            // Sign out current user
            try await auth.signOut()
            
            // Clear any cached data
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            
            // Clear any other app state/cache as needed
            // TODO: Add other cache clearing here if needed
            
            // Reset view model state
            isAnonymous = true
            userEmail = nil
            errorMessage = nil
            
            // Firebase will auto-create new anonymous user due to app initialization
        } catch {
            errorMessage = "Failed to reset account"
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
