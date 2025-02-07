import FirebaseFirestore

struct Event: Identifiable, Codable {
    let id: String
    let placeId: String                // The event is hosted at a specific Place
    let name: String
    let description: String?
    let startTime: Timestamp
    let endTime: Timestamp?
    let tags: [FilterCategory]         // Use the same tagging system as Place and Content
    let thumbnailUrl: String?
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    init(
        id: String,
        placeId: String,
        name: String,
        description: String? = nil,
        startTime: Timestamp,
        endTime: Timestamp? = nil,
        tags: [FilterCategory] = [],
        thumbnailUrl: String? = nil,
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp()
    ) {
        self.id = id
        self.placeId = placeId
        self.name = name
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.tags = tags
        self.thumbnailUrl = thumbnailUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 