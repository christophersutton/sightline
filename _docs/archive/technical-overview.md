# Technical Architecture PRD: Local Video Guide MVP

## 1. System Overview

### A. iOS Mobile App
Primary user-facing application for landmark detection and content viewing.

Tech Stack Decision Points (Updated):
1. **Swift Native** confirmed for:
   - Direct camera hardware access
   - Native MapKit integration
   - Firebase iOS SDK compatibility
   - Future ARKit expansion

### B. Firebase Backend Services
Core infrastructure components:
1. **Authentication**  
   - Anonymous sessions → Full accounts
   - Social login providers
   - Secure token handling

2. **Firestore Database**  
   - Real-time content sync
   - User preference storage
   - Landmark metadata

3. **Cloud Functions**  
   - AI processing pipeline
   - Content moderation
   - Third-party API orchestration

4. **Cloud Storage**  
   - Video upload/processing
   - Asset versioning
   - CDN delivery
   - Static map image storage

5. **Cloud Functions (New Section)**
   - Map image generation via Google Maps Static API
   - Deep link URL construction
   - Landmark location validation

## 2. iOS App Architecture (Updated)

### A. Core Components
1. **Camera System**
   - Frame capture → Firebase Vision preprocessing
   - Landmark detection pipeline:
     1. Google Landmark Detection API (primary)
     2. MLLM visual analysis fallback
     3. Confidence scoring system

2. **Content Player**
   - Firebase Storage video streaming
   - Offline caching strategy
   - Category management via Firestore

3. **Location Interface**
   - Static map images generated server-side
   - Landmark coordinates with deep links:
     - `maps://` for Apple Maps
     - `https://www.google.com/maps` for Google Maps
   - Tap-to-navigate functionality
   - Cached map tiles for offline use

### B. Data Models (Updated)

```swift
struct Landmark {
    let id: String
    let name: String
    let coordinates: GeoPoint
    let staticMapURL: String // Pre-rendered map image
    let directionsDeepLink: String // maps:// or googlemaps:// URL
    let detectionMetadata: [String: Any]
    let mllmFallbackAnalysis: String?
}

struct Content {
    let id: String
    let firebasePath: String
    let moderationStatus: ModerationStatus
    let aiMetadata: [String: Any] // Extracted entities
    let unlockRequirements: UnlockTier
}
```

## 3. AI/ML Integration

### A. Processing Pipeline
1. **Client-Side**  
   - Frame preprocessing
   - Basic object detection
   - Network optimization

2. **Cloud Functions**

```typescript
   export processContent = functions.storage.object().onFinalize(async (object) => {
     // Google Vision API
     const visionResults = await analyzeWithGoogleVision(object);
     
     // Fallback to OpenAI if needed
     if (visionResults.confidence < 0.7) {
       const openAIResults = await callOpenAIVisionAPI(object);
       await storeAnalysisResults(openAIResults);
     }
     
     // Moderation check
     await runContentModeration(object);
   });
```

### B. Key Services
1. **Google Cloud**  
   - Landmark Detection API
   - Places API (location details)
   - Cloud Vision (image analysis)

2. **OpenAI**  
   - GPT-4 Vision (fallback analysis)
   - Metadata extraction
   - Content summarization

3. **Firebase ML**  
   - On-device model serving
   - Custom model deployment

## 4. Updated MVP Development Plan

### Week 1: Core App
1. Firebase integration
   - Anonymous auth flow
   - Firestore data modeling
   - Cloud Storage setup

2. Camera system
   - Google Vision API integration
   - Basic confidence display

3. Content pipeline
   - Firebase video streaming
   - Simple moderation rules
   - Static map generation workflow

### Week 2: AI Features
1. MLLM fallback system
   - OpenAI integration
   - Confidence comparison UI

2. Automated moderation
   - NSFW detection
   - Quality scoring

3. Metadata extraction
   - Business hour parsing
   - Price range detection

## 5. Error Handling Strategy

### Critical Paths
1. Landmark Detection Fallback:
   ```swift
   func handleDetectionError(_ error: Error) {
     if isVisionAPIError(error) {
       initiateMLLMFallback()
       logErrorToCrashlytics(error)
     }
   }
   ```

2. Content Upload Recovery:
   - Resumeable uploads
   - Local draft saving
   - Moderation retry queue

### Monitoring
- Firebase Crashlytics integration
- LangFuse for AI pipeline observability
- Cloud Function logging

