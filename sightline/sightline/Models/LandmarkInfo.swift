import Foundation
import FirebaseFirestore
import CoreLocation

/// Simple struct to hold essential landmark data from the Vision API & neighborhood fetch.
struct LandmarkInfo: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double?
    let longitude: Double?
    let neighborhood: Neighborhood?

    init(name: String,
         latitude: Double? = nil,
         longitude: Double? = nil,
         neighborhood: Neighborhood? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.neighborhood = neighborhood
    }
}

/// Represents a location that can be displayed on a map
struct LandmarkLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}