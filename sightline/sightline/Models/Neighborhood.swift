import FirebaseFirestore  // For GeoPoint

struct Neighborhood: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let name: String
    let description: String?
    let imageUrl: String?
    let bounds: GeoBounds
    let landmarks: [Landmark]?
    
    struct GeoBounds: Codable {
        struct Point: Codable {
            let lat: Double
            let lng: Double
        }
        let northeast: Point
        let southwest: Point
    }
    
    struct Landmark: Codable {
        let location: GeoPoint
        let mid: String
        let name: String
    }
    
    static func == (lhs: Neighborhood, rhs: Neighborhood) -> Bool {
        return lhs.id == rhs.id
    }
}
