import Foundation

/// Represents the video processing states, matching the backend implementation
enum ProcessingState: String {
    // Initial states
    case created = "created"
    
    // Processing pipeline states
    case readyForTranscription = "ready_for_transcription"
    case readyForModeration = "ready_for_moderation"
    case readyForTagging = "ready_for_tagging"
    
    // Terminal states
    case complete = "complete"
    case rejected = "rejected"
    case failed = "failed"
    
    // UI-specific states (not persisted to backend)
    case notStarted
    case uploading
    
    var description: String {
        switch self {
        case .notStarted:
            return ""
        case .uploading:
            return "Uploading video..."
        case .created:
            return "Preparing upload..."
        case .readyForTranscription:
            return "Transcribing audio..."
        case .readyForModeration:
            return "Checking content..."
        case .readyForTagging:
            return "Analyzing content..."
        case .complete:
            return "Complete!"
        case .rejected:
            return "Content was rejected"
        case .failed:
            return "Processing failed"
        }
    }
    
    var stepIndex: Int {
        switch self {
        case .notStarted: return -1
        case .uploading: return 0
        case .created: return 0  // Same as uploading
        case .readyForTranscription: return 1
        case .readyForModeration: return 2
        case .readyForTagging: return 3
        case .complete: return 4
        case .rejected: return -1 // Terminal state like failed
        case .failed: return -1
        }
    }
    
    var isErrorState: Bool {
        switch self {
        case .failed, .rejected:
            return true
        default:
            return false
        }
    }
    
    var errorMessage: String {
        switch self {
        case .rejected:
            return "This content couldn't be posted. It may contain inappropriate material."
        case .failed:
            return "Something went wrong. Please try again."
        default:
            return ""
        }
    }
    
    static var allSteps: [(state: ProcessingState, message: String)] = [
        (.uploading, "Uploading your video..."),
        (.readyForTranscription, "Listening carefully to every word..."),
        (.readyForModeration, "Making sure everything's family-friendly..."),
        (.readyForTagging, "Adding some magic tags..."),
        (.complete, "All done! Looking great!")
    ]
} 