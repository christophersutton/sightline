import FirebaseFirestore

struct Content: Identifiable, Codable, Equatable {
    let id: String
    let placeIds: [String]      // References to one or more Places
    let eventIds: [String]?     // Optional references to one or more Events
    let neighborhoodId: String
    let authorId: String
    
    // Media
    var videoUrl: String
    let thumbnailUrl: String
    
    // Content details
    let caption: String
    let tags: [FilterCategory]  // Using the same FilterCategory for consistency
    
    // Metrics
    let likes: Int
    let views: Int
    
    // Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    // Processing status
    var processingStatus: ProcessingStatus
    var transcription: String?
    var moderationResults: ModerationResults?
    var processingError: ProcessingError?
    
    // Equatable implementation (ignoring timestamps and simple comparisons)
    static func == (lhs: Content, rhs: Content) -> Bool {
        lhs.id == rhs.id &&
        lhs.placeIds == rhs.placeIds &&
        lhs.eventIds == rhs.eventIds &&
        lhs.neighborhoodId == rhs.neighborhoodId &&
        lhs.authorId == rhs.authorId &&
        lhs.videoUrl == rhs.videoUrl &&
        lhs.thumbnailUrl == rhs.thumbnailUrl &&
        lhs.caption == rhs.caption &&
        lhs.tags == rhs.tags &&
        lhs.likes == rhs.likes &&
        lhs.views == rhs.views &&
        lhs.processingStatus == rhs.processingStatus &&
        lhs.transcription == rhs.transcription &&
        lhs.moderationResults == rhs.moderationResults &&
        lhs.processingError == rhs.processingError
    }
    
    init(
        id: String,
        placeIds: [String],
        eventIds: [String]? = nil,
        neighborhoodId: String,
        authorId: String,
        videoUrl: String,
        thumbnailUrl: String,
        caption: String,
        tags: [FilterCategory],
        likes: Int,
        views: Int,
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp(),
        processingStatus: ProcessingStatus,
        transcription: String? = nil,
        moderationResults: ModerationResults? = nil,
        processingError: ProcessingError? = nil
    ) {
        self.id = id
        self.placeIds = placeIds
        self.eventIds = eventIds
        self.neighborhoodId = neighborhoodId
        self.authorId = authorId
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.tags = tags
        self.likes = likes
        self.views = views
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.processingStatus = processingStatus
        self.transcription = transcription
        self.moderationResults = moderationResults
        self.processingError = processingError
    }
}

enum ProcessingStatus: String, Codable {
    case uploading
    case transcribing
    case moderating
    case tagging
    case complete
    case rejected
}

struct ModerationResults: Codable, Equatable {
    let flagged: Bool
    let categories: [String: Bool]
    let categoryScores: [String: Double]
}

struct ProcessingError: Codable, Equatable {
    let stage: String
    let message: String
    let timestamp: Date
} 
