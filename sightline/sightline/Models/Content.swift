import FirebaseFirestore

struct Content: Identifiable, Codable, Equatable {
    let id: String
    let placeIds: [String]      // References to one or more Places
    let eventIds: [String]?     // Optional references to one or more Events
    let neighborhoodId: String
    let authorId: String?      // Same as userId in Firestore
    let userId: String?         // Added for Firebase auth user ID
    
    // Media
    var videoUrl: String      // Google Cloud Storage path (gs://<bucket>/<path>)
    let thumbnailUrl: String
    let fileFormat: String?   // e.g. "mp4"
    
    // Content details
    let caption: String
    let tags: [FilterCategory]  // Using the same FilterCategory for consistency
    
    // Metrics
    let likes: Int
    let views: Int
    
    // Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    let startedAt: Timestamp?
    
    // Processing status
    var processingStatus: ProcessingStatus
    var transcriptionText: String?  // Renamed from transcription to match Firestore
    var moderationResults: ModerationResults?
    var processingError: ProcessingError?
    
    // Equatable implementation (ignoring timestamps and simple comparisons)
    static func == (lhs: Content, rhs: Content) -> Bool {
        lhs.id == rhs.id &&
        lhs.placeIds == rhs.placeIds &&
        lhs.eventIds == rhs.eventIds &&
        lhs.neighborhoodId == rhs.neighborhoodId &&
        lhs.authorId == rhs.authorId &&
        lhs.userId == rhs.userId &&
        lhs.videoUrl == rhs.videoUrl &&
        lhs.thumbnailUrl == rhs.thumbnailUrl &&
        lhs.caption == rhs.caption &&
        lhs.tags == rhs.tags &&
        lhs.likes == rhs.likes &&
        lhs.views == rhs.views &&
        lhs.processingStatus == rhs.processingStatus &&
        lhs.transcriptionText == rhs.transcriptionText &&
        lhs.moderationResults == rhs.moderationResults &&
        lhs.processingError == rhs.processingError
    }
    
    init(
        id: String,
        placeIds: [String],
        eventIds: [String]? = nil,
        neighborhoodId: String,
        authorId: String? = nil,
        userId: String? = nil,
        videoUrl: String,
        thumbnailUrl: String,
        fileFormat: String? = nil,
        caption: String,
        tags: [FilterCategory],
        likes: Int,
        views: Int,
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp(),
        startedAt: Timestamp? = nil,
        processingStatus: ProcessingStatus,
        transcriptionText: String? = nil,
        moderationResults: ModerationResults? = nil,
        processingError: ProcessingError? = nil
    ) {
        self.id = id
        self.placeIds = placeIds
        self.eventIds = eventIds
        self.neighborhoodId = neighborhoodId
        self.authorId = authorId
        self.userId = userId
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.fileFormat = fileFormat
        self.caption = caption
        self.tags = tags
        self.likes = likes
        self.views = views
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.processingStatus = processingStatus
        self.transcriptionText = transcriptionText
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
    let stage: String?
    let message: String?
    let timestamp: Date?
} 
