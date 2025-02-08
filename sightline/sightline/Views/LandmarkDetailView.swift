/// This is the old landmark detail view that we are replacing with the new one

// import SwiftUI
// import MapKit
// import os

// struct LandmarkDetailView: View {
//     let landmark: LandmarkInfo

//     @State private var region = MKCoordinateRegion(
//         center: CLLocationCoordinate2D(latitude: 30.0, longitude: -97.0),
//         span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//     )

//     private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Sightline", category: "LandmarkDetailView")

//     // Compute annotation if we have valid coordinates
//     private var mapAnnotations: [LandmarkLocation] {
//         guard let lat = landmark.latitude,
//               let lon = landmark.longitude,
//               CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else {
//             return []
//         }
        
//         return [
//             LandmarkLocation(
//                 name: landmark.name,
//                 coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
//             )
//         ]
//     }

//     var body: some View {
//         ScrollView {
//             VStack(alignment: .leading, spacing: 16) {
//                 // Header section
//                 VStack(alignment: .leading, spacing: 8) {
//                     Text(landmark.name)
//                         .font(.title)
//                         .bold()
                    
//                     if let lat = landmark.latitude, let lon = landmark.longitude {
//                         Text("Location: \(String(format: "%.4f°N", lat)), \(String(format: "%.4f°W", abs(lon)))")
//                             .font(.subheadline)
//                             .foregroundColor(.secondary)
//                     }
//                 }
                
//                 // Neighborhood section if available
//                 if let nb = landmark.neighborhood {
//                     VStack(alignment: .leading, spacing: 8) {
//                         Text("Neighborhood")
//                             .font(.headline)
                        
//                         Text(nb.name)
//                             .font(.body)
                        
//                         if let description = nb.description {
//                             Text(description)
//                                 .font(.body)
//                                 .foregroundColor(.secondary)
//                         }
//                     }
//                     .padding(.vertical, 8)
//                 }
                
//                 Divider()
                
//                 // Map section
//                 if !mapAnnotations.isEmpty {
//                     VStack(alignment: .leading, spacing: 8) {
//                         Text("Location")
//                             .font(.headline)
                        
//                         Map(coordinateRegion: $region,
//                             annotationItems: mapAnnotations) { location in
//                             MapMarker(coordinate: location.coordinate, tint: .red)
//                         }
//                         .frame(height: 250)
//                         .cornerRadius(12)
//                         .onAppear {
//                             if let lat = landmark.latitude, let lon = landmark.longitude {
//                                 region = MKCoordinateRegion(
//                                     center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
//                                     span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                                 )
//                             }
//                         }
//                     }
//                 }
//             }
//             .padding()
//         }
//         .navigationBarTitleDisplayMode(.inline)
//     }
// }