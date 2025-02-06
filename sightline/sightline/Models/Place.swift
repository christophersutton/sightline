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
    let details: [String: String]
    
    // For filtering/searching
    let tags: [String]
    
    // Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    init(id: String, name: String, category: String, rating: Double, reviewCount: Int, coordinates: GeoPoint, neighborhoodId: String, address: String, thumbnailUrl: String?, details: [String: String], tags: [String], createdAt: Timestamp = Timestamp(), updatedAt: Timestamp = Timestamp()) {
        self.id = id
        self.name = name
        self.category = category
        self.rating = rating
        self.reviewCount = reviewCount
        self.coordinates = coordinates
        self.neighborhoodId = neighborhoodId
        self.address = address
        self.thumbnailUrl = thumbnailUrl
        self.details = details
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 