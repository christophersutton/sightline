import SwiftUI
import MapKit

struct NeighborhoodUnlockedView: View {
    let neighborhood: Neighborhood
    let landmark: LandmarkInfo
    let onContinue: () -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.0, longitude: -97.0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Neighborhood Unlocked!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.yellow)
                .padding(.top, 80)

            Text(neighborhood.name)
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if let description = neighborhood.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Display map centered on the landmark's lat/lng
            Map(
                coordinateRegion: $region,
                annotationItems: [
                    LandmarkLocation(
                        name: landmark.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: landmark.latitude ?? 30.0,
                            longitude: landmark.longitude ?? -97.0
                        )
                    )
                ]
            ) { location in
                MapMarker(coordinate: location.coordinate, tint: .red)
            }
            .frame(height: 220)
            .cornerRadius(12)
            .padding(.horizontal)
            .onAppear {
                if let lat = landmark.latitude, let lon = landmark.longitude {
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }

            // "Continue" Button
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height)
        .background(.thinMaterial)
        .ignoresSafeArea()
        .onAppear {
            print("🔷 NeighborhoodUnlockedView appeared")
        }
        .task {
            print("🔷 NeighborhoodUnlockedView task started")
            // Log any expensive operations happening here
        }
    }
}

struct NeighborhoodUnlockedView_Previews: PreviewProvider {
    static var previews: some View {
        NeighborhoodUnlockedView(
            neighborhood: Neighborhood(
                id: "test",
                name: "Test Neighborhood",
                description: "Sample description",
                imageUrl: nil,
                bounds: Neighborhood.GeoBounds(
                    northeast: .init(lat: 30.2, lng: -97.7),
                    southwest: .init(lat: 30.1, lng: -97.8)
                ),
                landmarks: nil
            ),
            landmark: LandmarkInfo(name: "Test Landmark", latitude: 30.2, longitude: -97.7),
            onContinue: {}
        )
    }
}
