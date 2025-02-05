import FirebaseFirestore

struct Place: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let rating: Double
    let reviewCount: Int
    let coordinates: GeoPoint
    let neighborhoodId: String
    let address: String
    let thumbnailUrl: String?
    
    // For places like restaurants that might have additional info
    let details: [String: String]?
    
    // For filtering/searching
    let tags: [String]
    
    // Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
} 