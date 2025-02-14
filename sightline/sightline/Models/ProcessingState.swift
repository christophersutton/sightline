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
} 