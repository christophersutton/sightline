import FirebaseFirestore  // For GeoPoint

struct Neighborhood: Identifiable, Codable {
    let id: String
    let name: String
    let formattedAddress: String
    let bounds: GeoBounds
    
    enum CodingKeys: String, CodingKey {
        case id = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case bounds
    }
}

struct GeoBounds: Codable {
    let northeast: GeoPoint
    let southwest: GeoPoint
}
