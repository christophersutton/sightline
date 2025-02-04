# Technical Requirements

## 2.1 iOS App

### Platform
- iOS 15+ (Swift 5.x)

### Key Libraries
- Firebase iOS SDK (Auth, Firestore, Storage, etc.)
- AVFoundation (for video capture/playback)
- SwiftUI or UIKit (developer preference—no strict requirement)

### Core Features

#### Camera Landmark Detection
- Real-time or snapshot-based detection using Google Landmark API
- Fallback: none for Week 1

#### Content Feed
- Display list/grid of videos from Firestore
- Stream from Firebase Storage

#### Location Details
- Show static map image (server-generated or Google Static Maps)
- Deep link to Apple Maps for directions

#### User Accounts
- Anonymous Auth → Social/Email upgrade
- Store user data in Firestore under `users/{userId}`

#### Video Recording & Upload
- Capture short-form videos with AVFoundation
- Upload to Firebase Storage -> Cloud Function triggers AI processing

### Data Models (iOS Layer)

```swift
struct UserProfile {
    let uid: String
    let isAnonymous: Bool
    let savedPlaces: [String] // array of place IDs
}

struct Place {
    let placeId: String
    let name: String
    let coordinates: (lat: Double, lng: Double)
    let isLandmark: Bool
    let unlocked: Bool
    // Additional fields as needed
}

struct VideoContent {
    let videoId: String
    let storagePath: String
    let placeId: String
    let uploaderId: String
    // Basic metadata: title, category, etc.
}
```

## 2.2 Firebase Backend

### Services
- Authentication (anonymous, upgrade to full account)
- Firestore for storing user data, place data, video metadata
- Cloud Storage for uploaded videos
- Cloud Functions for AI tasks (Week 2)

### Firestore Structure

```yaml
Copy
users/
  {userId}/
    savedPlaces: [ {placeId}, ... ]
places/
  {placeId}/
    name: "Golden Gate Bridge"
    coordinates: ...
    ...
videos/
  {videoId}/
    placeId: ...
    uploaderId: ...
    moderationStatus: "approved" | "flagged"
```


### Cloud Functions

- `onFinalize` for video uploads → triggers AI pipeline (categorization, moderation, etc.) in Week 2
- Potential HTTP endpoints for fallback detection or additional functionality

## 2.3 AI Integrations (Week 2)

- **Google Landmark API**: Primary detection
- **Fallback MLLM**: If Landmark API fails or confidence < threshold
- **Content Moderation**: Basic NSFW / vulgar language detection
- **Metadata Extraction**: Business hours, price range, etc.
