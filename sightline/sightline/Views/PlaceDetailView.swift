import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth
import os

// Add this enum near the top of the file
enum PlaceDetailMode {
    case discovery   // Default mode when discovering new places
    case review     // Mode when viewing from profile/saved places
}

struct PlaceDetailView: View {
    let placeId: String
    let mode: PlaceDetailMode  // Add this property
    @StateObject private var viewModel: PlaceDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState  // for navigation
    
    // Add state for sheet height
    @State private var sheetHeight: CGFloat = UIScreen.main.bounds.height * 0.7
    @State private var offset: CGFloat = 0

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.0, longitude: -97.0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // Add error state
    @State private var showError = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sightline", category: "PlaceDetailView")

    init(placeId: String, mode: PlaceDetailMode = .discovery) {  // Update initializer
        self.placeId = placeId
        self.mode = mode
        _viewModel = StateObject(wrappedValue: PlaceDetailViewModel())
    }

    func openDirections() {
        guard let place = viewModel.place else { return }
        
        let coordinates = "\(place.coordinates.latitude),\(place.coordinates.longitude)"
        let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "http://maps.apple.com/?daddr=\(coordinates)&name=\(name)")
        
        if let url = url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            viewModel.errorMessage = "Unable to open Maps"
        }
    }
    
    var directionsButton: some View {
        Button(action: openDirections) {
            HStack {
                Image(systemName: "map.fill")
                Text("Get Directions")
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .disabled(viewModel.place == nil)
        .opacity(viewModel.place == nil ? 0.6 : 1.0)
    }
    
    var actionButton: some View {
        switch mode {
        case .discovery:
            return savePlaceButton
        case .review:
            return leaveReviewButton
        }
    }
    
    var savePlaceButton: some View {
        Button(action: {
            Task {
                await viewModel.savePlace()
                // After saving, navigate to Profile tab
                appState.shouldSwitchToProfile = true
                dismiss()
            }
        }) {
            HStack {
                Image(systemName: "heart.fill")
                Text("Save Place")
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.pink)
            .cornerRadius(10)
        }
        .disabled(viewModel.place == nil)
        .opacity(viewModel.place == nil ? 0.6 : 1.0)
    }

    var leaveReviewButton: some View {
        Button(action: {
            // TODO: Implement review flow
        }) {
            HStack {
                Image(systemName: "star.fill")
                Text("Leave a Review")
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.orange)
            .cornerRadius(10)
        }
        .disabled(viewModel.place == nil)
        .opacity(viewModel.place == nil ? 0.6 : 1.0)
    }

    var mapView: some View {
        Group {
            if let place = viewModel.place {
                Map(coordinateRegion: $region, annotationItems: [place]) { place in
                    MapMarker(
                        coordinate: CLLocationCoordinate2D(
                            latitude: place.coordinates.latitude,
                            longitude: place.coordinates.longitude
                        ),
                        tint: .red
                    )
                }
                .onAppear {
                    // More defensive region initialization
                    let coordinate = CLLocationCoordinate2D(
                        latitude: place.coordinates.latitude,
                        longitude: place.coordinates.longitude
                    )
                    if CLLocationCoordinate2DIsValid(coordinate) {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    } else {
                        logger.warning("Invalid coordinates for place: \(place.id)")
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
    }

    var headerView: some View {
        Text(viewModel.place?.name ?? "Loading...")
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)  // Centers the text
            .padding(.top, 16)           // More breathing room above
            .padding(.bottom, 8)         // Consistent padding below
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    headerView
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Description area
                    Text(viewModel.place?.description ?? "No description available.")
                        .font(.body)
                        .padding(.horizontal)

                    mapView
                    
                    directionsButton
                    actionButton
                }
            }
            .frame(maxWidth: geometry.size.width)
            .background(.ultraThinMaterial)  // Translucent material background
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .presentationDetents([
            .height(400),
            .large
        ])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .presentationBackground(.ultraThinMaterial)  // Makes the whole sheet translucent
        .onAppear {
            Task {
                await viewModel.loadPlaceDetails(placeId: placeId)
            }
        }
    }
}

@MainActor
final class PlaceDetailViewModel: ObservableObject {
    @Published var place: Place?
    @Published var errorMessage: String?
    
    private let services = ServiceContainer.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sightline", category: "PlaceDetailView")

    func loadPlaceDetails(placeId: String) async {
        do {
            let fetchedPlace = try await services.firestore.fetchPlace(id: placeId)
            await MainActor.run {
                self.place = fetchedPlace
                self.errorMessage = nil
            }
        } catch {
            logger.error("Error loading place details: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Unable to load place details"
            }
        }
    }
    
    func savePlace() async {
        guard let place = self.place,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await services.firestore.savePlaceForUser(userId: userId, placeId: place.id)
        } catch {
            self.errorMessage = "Error saving place: \(error.localizedDescription)"
        }
    }
}
