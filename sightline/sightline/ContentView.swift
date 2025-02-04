import SwiftUI
import FirebaseAuth

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Hello, Firebase!")
                    .padding()
            }
            .onAppear {
                if Auth.auth().currentUser == nil {
                    Auth.auth().signInAnonymously { authResult, error in
                        if let error = error {
                            print("Error signing in anonymously: \(error.localizedDescription)")
                        } else if let user = authResult?.user {
                            print("Signed in anonymously with uid: \(user.uid)")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
