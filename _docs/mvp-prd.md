# MVP PRD: Sightline

## Objectives
- Deliver a seamless, short-form video experience driven by local content.
- Use landmark detection as a strategic trigger to unlock a curated video feed for a given area.
- Incorporate AI-driven categorization and content moderation to ensure content relevance and quality.
- Utilize Firebase services for authentication, real-time synchronization, and backend processing.

## Core User Flows (Based on MVP User Stories)
1. **Discovery & Feed Unlock Flow:**
   - **Landmark Detection as the Hook:**  
     The app's native camera continuously scans for landmarks. When a landmark is detected, it isn't the final destination—instead, it unlocks a curated feed of short-form videos from the surrounding area.
   - **Content Feed Display:**  
     The feed shows locally relevant, AI-curated videos that capture the essence of the area, inviting users to explore more content and engage with the community.
   - **Engagement Opportunities:**  
     Users can interact with videos, save favorites, or engage in actions that may unlock additional features or premium content in the future.

2. **Anonymous Authentication & Account Upgrade:**
   - **Seamless Onboarding:**  
     Users begin with Firebase's anonymous authentication for frictionless access to content.
   - **Transition to Full Accounts:**  
     When users decide to save content, post, or access additional features, they can seamlessly upgrade their anonymous account to a full profile. Data migration is managed automatically through Firebase linking mechanisms.

3. **Video Playback & User Interaction:**
   - **Native Video Playback:**  
     A high-performance video player ensures smooth playback of short-form content.
   - **Engagement and Navigation:**  
     Although the initial trigger is landmark detection, the main interface focuses on an engaging video feed with intuitive user interactions for swiping, liking, and sharing content.

4. **AI Categorization & Content Moderation:**
   - **Content Analysis:**  
     As videos are uploaded or streamed, Firebase Cloud Functions call external AI services (e.g., Google Cloud Vision or custom ML endpoints) to analyze and categorize the content based on local relevance.
   - **Moderation Pipeline:**  
     A built-in moderation mechanism assesses video quality and flags content that does not meet quality or safety standards. This ensures the feed remains engaging and trustworthy.
   - **Integration & Error Handling:**  
     AI processing is tightly integrated with the backend using Cloud Functions, ensuring robust error handling, fallback strategies, and minimal processing latency.
   - **Extract structured metadata (business hours, price ranges) using vision-language models**
   - **Implement fallback MLLM analysis when Google Landmark API fails**

## Technical Considerations
- **iOS App (Swift Native):**  
  - Leverages robust native camera frameworks for real-time landmark detection.
  - Uses local caching (via Core Data or equivalent) to support smooth offline experiences and temporary data storage.
  - Provides integration hooks for forwarding video metadata and images to Firebase Cloud Functions for AI processing.
- **Firebase Backend:**
  - **Authentication:**  
    Implements a fluid transition from anonymous authentication to full user accounts, ensuring data integrity during the transition.
  - **Cloud Functions:**  
    Hosts essential functions that perform AI-based categorization and moderation, interfacing with external AI services and managing processing errors.
  - **Data Sync:**  
    Ensures real-time synchronization of the video feed and user activity, maintaining a responsive content delivery pipeline.
- **AI/ML Pipeline (MVP Level):**
  - Incorporates external AI services to identify, categorize, and moderate content.
  - Focuses on delivering immediate, relevant feedback for content uploads while ensuring an efficient and responsive user experience.
  - **Implement confidence scoring for location detection results**
  - **Create error recovery flows for failed video uploads**
  - **Establish Firebase Storage rules for user-generated content**

## Out of Scope (for MVP)
- Development of an advanced content generation pipeline (covered under future stretch goals in `/content-gen`).
- Extended analytics, cross-platform user interfaces, and complex offline caching beyond basic requirements. 