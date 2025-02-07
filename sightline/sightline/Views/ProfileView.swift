import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    private let services = ServiceContainer.shared
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.isAnonymous {
                    SignUpView(viewModel: viewModel)
                } else {
                    UserProfileView(viewModel: viewModel)
                }
            }
            .navigationTitle("Profile")
        }
        .onAppear {
            viewModel.checkAuthState()
        }
    }
}

// Sign Up Form
struct SignUpView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.title2)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
            }
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    await viewModel.signUp(email: email, password: password, confirmPassword: confirmPassword)
                }
            }) {
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(viewModel.isProcessing)
            
            Spacer()
        }
    }
}

// User Profile View
struct UserProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // User info
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
                
                Text(viewModel.userEmail ?? "")
                    .font(.headline)
            }
            .padding()
            
            Button(action: {
                Task {
                    await viewModel.signOut()
                }
            }) {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
            
            /* Debug Controls commented out
            #if DEBUG
            GroupBox(label: Text("Debug Controls")) {
                // ... existing debug controls ...
            }
            #endif
            */
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
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
