import FirebaseFirestore

struct Place: Identifiable, Codable {
    let id: String
    let name: String
    let primaryCategory: FilterCategory           // e.g., "restaurant", "bar"
    let tags: [FilterCategory]            // Controlled tags for searching and filtering
    
    // Other properties...
    let rating: Double
    let reviewCount: Int
    let coordinates: GeoPoint
    let neighborhoodId: String
    let address: String
    let thumbnailUrl: String?
    let details: [String: String]
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    init(
        id: String,
        name: String,
        primaryCategory: FilterCategory,
        tags: [FilterCategory],
        rating: Double,
        reviewCount: Int,
        coordinates: GeoPoint,
        neighborhoodId: String,
        address: String,
        thumbnailUrl: String?,
        details: [String: String],
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp()
    ) {
        self.id = id
        self.name = name
        self.primaryCategory = primaryCategory
        self.tags = tags
        self.rating = rating
        self.reviewCount = reviewCount
        self.coordinates = coordinates
        self.neighborhoodId = neighborhoodId
        self.address = address
        self.thumbnailUrl = thumbnailUrl
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 