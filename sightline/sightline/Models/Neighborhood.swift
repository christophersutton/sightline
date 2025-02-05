import FirebaseFirestore  // For GeoPoint

struct Neighborhood: Identifiable {
    let id: String // This will be the place_id
    let name: String
    let formattedAddress: String
    let bounds: GeoBounds
    
    init(from dict: [String: Any]) {
        self.id = dict["place_id"] as? String ?? ""
        self.name = dict["name"] as? String ?? ""
        self.formattedAddress = dict["formatted_address"] as? String ?? ""
        self.bounds = GeoBounds(from: dict["bounds"] as? [String: Any] ?? [:])
    }
}

struct GeoBounds {
    let northeast: GeoPoint
    let southwest: GeoPoint
    
    init(from dict: [String: Any]) {
        let ne = dict["northeast"] as? [String: Any] ?? [:]
        let sw = dict["southwest"] as? [String: Any] ?? [:]
        
        self.northeast = GeoPoint(
            latitude: ne["lat"] as? Double ?? 0,
            longitude: ne["lng"] as? Double ?? 0
        )
        self.southwest = GeoPoint(
            latitude: sw["lat"] as? Double ?? 0,
            longitude: sw["lng"] as? Double ?? 0
        )
    }
}

