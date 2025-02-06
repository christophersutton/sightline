import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    private let services = ServiceContainer.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Profile")
                    .font(.largeTitle)
                    .padding()
                
                #if DEBUG
                GroupBox(label: Text("Debug Controls")) {
                    VStack(spacing: 15) {
                      Button("Load Test Data") {
                                  Task {
                                      do {
                                          try await services.firestore.populateTestData()
                                          print("Test data loaded successfully.")
                                      } catch {
                                          print("Error loading test data: \(error)")
                                      }
                                  }
                              }
                              .buttonStyle(.borderedProminent)
                              .tint(Color.blue)
                              
                              Button("Delete Test Data") {
                                  Task {
                                      do {
                                          try await services.firestore.deleteAllTestData()
                                          print("Test data deleted successfully.")
                                      } catch {
                                          print("Error deleting test data: \(error)")
                                      }
                                  }
                              }
                              .buttonStyle(.borderedProminent)
                              .tint(Color.red)
                    }
                    .padding()
                }
                .padding()
                #endif

                Spacer()
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
