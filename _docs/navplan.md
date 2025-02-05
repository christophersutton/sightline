# Step-by-Step Implementation Plan for Updated Navigation Structure

## 1. Define the New Flow
- **Navigation Hierarchy:** Neighborhood → Category → Vertical scrolling list of Reels.
- **Reel Cell Interaction:**
  - The video area supports play/pause toggling when tapped.
  - A pill-style button, displaying the place name, is pinned to the right edge of the reel cell. Tapping this button navigates to the PlaceDetailView.

## 2. Update the Vertical Reels View
- **Layout Changes:**
  - Replace the current horizontal paging with a vertical list of reels.
  - Use a vertical `ScrollView` with a `LazyVStack` (or a vertical `TabView`) to display the reels.
- **Content Display:**
  - Ensure each reel cell uses your existing video player view (e.g., from `ContentItemView`) for video playback.
  - Overlay a pill-style navigation button on the right side of the reel cell.

## 3. Update ContentItemView
- **Add the Navigation Button:**
  - In `ContentItemView.swift`, add an overlay view that contains a small, rounded pill-style button.
  - Position the button so that it bumps against the right edge (with its left side rounded).
  - The button should display the associated place’s name.
  - Wrap this button in a `NavigationLink` that navigates to `PlaceDetailView`.
- **Adjust Gesture Handling:**
  - Attach a tap gesture recognizer to the video area (excluding the pill button) so that tapping anywhere else toggles play/pause.
  - Ensure the pill button’s hit area is separate and does not conflict with the play/pause gesture.

## 4. Create PlaceDetailView
- **New View Setup:**
  - Create a new SwiftUI view (e.g., `PlaceDetailView.swift`).
- **Layout:**
  - Display the place title and address at the top.
  - Include a horizontal carousel (using a horizontal `ScrollView` or a TabView with page style) to show all reels (content) associated with that place.
- **Simplified Content:**
  - For now, omit the thumbs up/thumbs down review controls.

## 5. Update Navigation and Integration
- **Navigation Stack:**
  - Ensure the overall navigation (e.g., via a `NavigationView`) supports pushing the `PlaceDetailView` when the pill button is tapped.
- **Integration:**
  - Update any relevant view models or data lookups so that the reel cell has access to the associated `Place` data (such as its name for the pill button).
  - Verify that the play/pause gesture on the video and the tap on the navigation pill function independently.
