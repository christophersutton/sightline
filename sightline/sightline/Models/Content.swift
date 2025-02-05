import FirebaseFirestore

enum ContentType: String, Codable {
    case restaurant = "restaurant"
    case event = "event"
    case highlight = "highlight"
}

struct Content: Identifiable, Codable {
    let id: String
    let placeId: String
    let authorId: String
    let type: ContentType
    
    // Media
    var videoUrl: String
    let thumbnailUrl: String
    
    // Content details
    let caption: String
    let tags: [String]
    
    // Metrics
    let likes: Int
    let views: Int
    
    // Location context
    let neighborhoodId: String
    
    // Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
} 