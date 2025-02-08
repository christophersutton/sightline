import SwiftUI
import MapKit

struct NeighborhoodUnlockedView: View {
    let neighborhood: Neighborhood
    let landmark: LandmarkInfo
    @Environment(\.dismiss) private var dismiss

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.0, longitude: -97.0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    Text("Neighborhood Unlocked!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.top, 40)

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

                    // Display map centered on the actual landmark's lat/lng
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
                    .onAppear {
                        // Same approach as LandmarkDetailView
                        if let lat = landmark.latitude, let lon = landmark.longitude {
                            region = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Dismiss Button
                    Button {
                        dismiss()
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
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground).opacity(0.9))
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled(false)
    }
}