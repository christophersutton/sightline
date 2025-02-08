# ContentFeedView Refactor Checklist

## Phase 1: Service Layer & Data Models
- [ ] Create ContentService
  - [ ] Move Firestore content fetching logic from ViewModel
  - [ ] Add proper error handling and retry logic
  - [ ] Add caching layer for content items
- [ ] Create NeighborhoodService  
  - [ ] Move neighborhood fetching logic from ViewModel
  - [ ] Add caching for neighborhood data
- [ ] Create PlaceService
  - [ ] Move place fetching logic from ViewModel
  - [ ] Add caching for frequently accessed places

## Phase 2: View Components (Can be worked on in parallel with Phase 1)
- [ ] Create NeighborhoodSelectorView
  - [ ] Extract neighborhood selection UI from ContentFeedView
  - [ ] Create dedicated NeighborhoodSelectorViewModel
  - [ ] Add proper loading/error states
- [ ] Create CategorySelectorView  
  - [ ] Extract category selection UI from ContentFeedView
  - [ ] Create dedicated CategorySelectorViewModel
  - [ ] Add proper loading/error states
- [ ] Create FeedContentView
  - [ ] Extract main feed content display from ContentFeedView
  - [ ] Move video player management here
  - [ ] Add proper loading states

## Phase 3: ViewModels & State Management
- [ ] Create MainFeedCoordinator
  - [ ] Handle navigation state
  - [ ] Manage communication between child ViewModels
  - [ ] Handle deep linking
- [ ] Refactor ContentFeedViewModel
  - [ ] Remove direct Firestore dependencies
  - [ ] Use new service layer
  - [ ] Add proper state management using Combine
  - [ ] Move video management to separate component
- [ ] Create VideoPlayerManager
  - [ ] Handle video preloading and playback
  - [ ] Add proper resource management
  - [ ] Handle background/foreground transitions

## Phase 4: Navigation & State Cleanup
- [ ] Implement proper navigation handling
  - [ ] Move sheet presentation logic to coordinator
  - [ ] Add proper deep linking support
  - [ ] Handle back navigation gracefully
- [ ] Clean up state management
  - [ ] Audit @Published properties
  - [ ] Ensure proper state restoration
  - [ ] Add proper error handling

## Phase 5: Testing & Documentation
- [ ] Add unit tests
  - [ ] Service layer tests
  - [ ] ViewModel tests
  - [ ] Coordinator tests
- [ ] Add UI tests
  - [ ] Basic navigation flows
  - [ ] Error states
  - [ ] Loading states
- [ ] Add documentation
  - [ ] Architecture overview
  - [ ] Component responsibilities
  - [ ] Common patterns used

Each phase should be independently compilable and testable. The phases can be worked on somewhat in parallel, but Phase 1 should be completed before Phase 3, and Phase 2 should be mostly complete before Phase 4.
