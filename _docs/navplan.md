# Updated Navigation Implementation Plan

This document outlines the detailed plan to implement dual-mode navigation for our app—one with a vertically scrolling feed for broad content exploration (with TikTok-like snapping, preloading, and smart audio transitions) and a horizontally swipeable Place Details view for exploring reels specific to a given place. In addition, the plan covers enhanced navigation for switching neighborhoods and categories.

---

## 1. Overview

The goal is to deliver a seamless, modern user experience by supporting two distinct interaction models:

- **Vertical Feed (Broad Exploration):**  
  Users scroll vertically through a list of reels. Videos should start preloading and begin playback as soon as they are in (or near) the viewport. As the user scrolls, snapping behavior ensures that a reel "locks" into place, and audio mixing immediately mutes or reduces the outgoing video's audio even if the snap isn't complete.

- **Place Details View (In-Depth Exploration):**  
  When a reel's pill button (which displays the place name) is tapped, the app navigates to a Place Details view. This view features a fixed header displaying the place information (name, address, etc.) and a horizontally swipeable carousel underneath to navigate between reels about that place.

- **Neighborhood & Category Navigation:**  
  The top section of the content feed will include two horizontally scrollable selectors for neighborhoods and categories. These selectors update the feed when changed and need to do so in a smooth, non-jarring manner.

---

## 2. Overall Architecture and State Management

- **Navigation:**  
  - Wrap `MainTabView` with a `NavigationStack` to enable deep navigation
  - Define navigation destination enum:
    ```swift
    enum NavigationDestination: Hashable {
        case placeDetail(placeId: String, initialContentId: String)
    }
    ```
  - Enhance `AppState` to include navigation path management

- **State Management:**  
  - Extend existing `ContentFeedViewModel` rather than creating new ones:
    - Add video preloading coordination
    - Add scroll position and snap state management
    - Add audio transition management
  - Create a new `PlaceDetailViewModel` for place-specific state

- **Video Player Management:**
  - Build upon existing `AVQueuePlayer` + `AVPlayerLooper` implementation
  - Add preloading manager to handle multiple `AVPlayer` instances:
    - Maintain pool of 3-4 preloaded players maximum
    - Implement cleanup strategy for unused players
  - Coordinate audio transitions between players during scroll

---

## 3. Vertical Feed Implementation

### Layout & Scrolling Behavior
- **Feed Construction:**  
  - Replace current horizontal `TabView` in `ContentFeedView` with `ScrollView`
  - Maintain existing `ContentItemView` structure but adapt for vertical layout
  - Add scroll position monitoring using `GeometryReader`
  
- **Snapping Mechanism:**  
  - Implement custom scroll view coordinator to handle snap behavior
  - Use `ScrollViewReader` for programmatic scrolling
  - Maintain smooth video playback during snap transitions

### Video Preloading and Audio Control
- **Enhanced ContentItemViewModel:**
  - Add preloading state management
  - Maintain existing looping behavior during playback
  - Add volume control for cross-fade support

- **Preloading Strategy:**
  - Preload maximum 2 videos ahead and 1 behind current position
  - Implement memory-aware cleanup of distant preloaded content
  - Maintain existing video cleanup pattern from `ContentItemViewModel`

---

## 4. Place Details View Implementation

### Layout
- **Header:**  
  - Create a fixed header at the top of the `PlaceDetailView` that displays the place's name, address, and other pertinent details.
  
- **Horizontal Reel Carousel:**  
  - Below the header, implement a horizontally swipeable carousel using a `TabView` with the `.page` style.
  - Each cell in this carousel will display content similarly to `ContentItemView`; however, it can optionally share state (or simply restart video playback) to ensure smooth transitions.

### Transition from the Feed
- **Navigation Trigger:**  
  - Update `ContentItemView` with an overlay "pill" button. This button should be wrapped in a `NavigationLink` (or trigger programmatic navigation via the `NavigationStack` path) that pushes the Place Details view.
  
- **Seamless Context Passing:**  
  - Pass along the necessary place data (or an identifier to fetch data) and, if possible, any relevant video playback context to ensure a smooth transition between the broad feed and detail view.

---

## 5. Neighborhood and Category Filtering

### Interaction Model
- **Selectors:**  
  - At the top of the vertical feed, implement two horizontal scroll selectors:
    - **Neighborhood Selector:** Displays available neighborhoods. Tapping a neighborhood updates the active selection in the view model.
    - **Category Selector:** Shows content categories (e.g., Restaurants, Events). Changes update the feed state accordingly.
  
- **Smooth Transitions:**  
  - Implement smooth animations on selection change.
  - Consider debouncing input if rapid selection could trigger heavy content reloads.
  - Ensure that changing either filter instantly updates the content area while showing a temporary loading indicator if needed.

### State Synchronization
- Enhance `ContentFeedViewModel` with functions that:
  - Handle neighborhood and category changes by refreshing the content feed smoothly.
  - Optionally preload adjacent content based on the new selection.
  - Keep the UI responsive by offloading heavy data fetching to background tasks controlled via async/await.

---

## 6. Integration & Detailed State Management

### Video Player Coordination
- **Player Pool Management:**
  ```swift
  class VideoPlayerPool {
      private var preloadedPlayers: [String: AVQueuePlayer] // keyed by content ID
      private let maxPreloadedPlayers = 4
      
      func preloadVideo(for contentId: String)
      func cleanupDistantPlayers()
  }
  ```

- **Audio Transition Handling:**
  - Implement volume ramping between players
  - Maintain existing mute state management
  - Add cross-fade duration configuration

### Memory Management
- **Resource Limits:**
  - Set maximum of 4 preloaded videos at any time
  - Implement aggressive cleanup of unused video resources
  - Add memory pressure handling

- **Performance Monitoring:**
  - Add video preload time tracking
  - Monitor memory usage during scroll operations
  - Implement adaptive preloading based on device capabilities

### NavigationStack Integration
- **Global Navigation Setup:**  
  - Wrap the main content views (`ContentFeedView`, `PlaceDetailView`, etc.) in a `NavigationStack` linked to a global navigation path (e.g., maintained in `AppState`).
  
- **Navigation Destinations:**  
  - Define explicit navigation destinations so that tapping on the pill button in any reel cleanly pushes the Place Detail view.

### Video Playback & Preloading Coordination
- **Centralized Control:**  
  - Consider a shared video player state in the view model (or even a dedicated controller) to help manage preloading, volume transitions, and playback continuity between cells.
  
- **Async Coordination:**  
  - Utilize async methods or Combine pipelines to handle asynchronous loading of video content, ensuring that preloading and audio adjustments trigger reliably based on scroll events and snapping detection.

---

## 7. Testing & Performance Optimization

- **Unit & UI Testing:**  
  - Test the snapping logic using simulated scroll events.
  - Validate that preloading and audio transitions occur as expected through unit tests on the view models.
  - Manually test transitions between neighborhoods/categories to monitor for jank.

- **Performance Profiling:**  
  - Check memory usage during heavy scrolling to ensure that the preloading of videos does not leak resources.
  - Profile the responsiveness of the vertical feed to determine if further optimizations (or a shift to a more complex UICollectionView wrapper) become necessary.

---

## Conclusion

This updated plan details a dual-mode navigation structure that leverages both a TikTok-inspired vertical feed and a horizontally swipeable details view. It incorporates smart preloading, proactive audio control, and smooth transitions for neighborhood and category changes—all managed by a robust state management solution under a modern `NavigationStack` framework.

This plan should provide a clear roadmap for implementation. The focus is on delivering a smooth, responsive, and modern UX for the demo, even if that necessitates more complex state management to keep everything in sync.
