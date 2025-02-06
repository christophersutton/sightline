import FirebaseFirestore

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case restaurant = "restaurant"
    case event = "event"
    case highlight = "highlight"
    
    var id: String { rawValue }
}

struct Content: Identifiable, Codable, Equatable {
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
    
    // Implement Equatable manually since Timestamp might not conform to it
    static func == (lhs: Content, rhs: Content) -> Bool {
        lhs.id == rhs.id &&
        lhs.placeId == rhs.placeId &&
        lhs.authorId == rhs.authorId &&
        lhs.type == rhs.type &&
        lhs.videoUrl == rhs.videoUrl &&
        lhs.thumbnailUrl == rhs.thumbnailUrl &&
        lhs.caption == rhs.caption &&
        lhs.tags == rhs.tags &&
        lhs.likes == rhs.likes &&
        lhs.views == rhs.views &&
        lhs.neighborhoodId == rhs.neighborhoodId
    }
    
    init(id: String, placeId: String, authorId: String, type: ContentType, videoUrl: String, thumbnailUrl: String, caption: String, tags: [String], likes: Int, views: Int, neighborhoodId: String, createdAt: Timestamp = Timestamp(), updatedAt: Timestamp = Timestamp()) {
        self.id = id
        self.placeId = placeId
        self.authorId = authorId
        self.type = type
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.tags = tags
        self.likes = likes
        self.views = views
        self.neighborhoodId = neighborhoodId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 