# Sightline: Discover Your City's Stories

Sightline is a mobile application that helps you explore your city in a new way. By identifying landmarks through your camera, you can unlock content and stories about the places around you.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Firebase Integration](#firebase-integration)
    - [Cloud Functions](#cloud-functions)
    - [Firestore](#firestore)
    - [Firebase Storage](#firebase-storage)
    - [Authentication](#authentication)
- [iOS Application (SwiftUI)](#ios-application-swiftui)
    - [Models](#models)
    - [Services](#services)
    - [State Management](#state-management)
    - [Views](#views)
    - [Landmark Detection](#landmark-detection-ios)
    - [Video Playback](#video-playback)
- [Development Setup](#development-setup)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Configuration](#configuration)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license) (This section is added, assuming a license will be added)
- [Code Overview (Repomix)](#code-overview-repomix)

## Features

-   **Landmark Detection:** Use your camera to identify landmarks and unlock content related to them.
-   **Content Feed:** Browse a curated feed of videos and information about places and events in your unlocked neighborhoods.
-   **Neighborhood-Based Content:** Content is organized by neighborhoods, which are unlocked by discovering landmarks within them.
-   **Category Filtering:** Filter content by categories such as restaurants, events, music, art, and more.
-   **Place Details:** View detailed information about places, including descriptions, addresses, and user-generated content.
-   **User Profiles:** Create an account to save places and manage your content (future feature).
-   **Anonymous Authentication:**  Start exploring immediately with anonymous sign-in; create an account later to save progress.
-   **Video Caching & Preloading:** Optimized video playback with caching and preloading of content.

## Project Structure

The repository is organized into two main parts:

-   **`firebase/`**: Contains the backend logic and configuration for Firebase, including Cloud Functions, Firestore rules, and storage rules.
-   **`sightline/`**: Contains the Xcode project for the iOS application.

├── firebase/ # Firebase backend
│ ├── functions/ # Cloud Functions
│ │ ├── .eslintrc.json
│ │ ├── .gitignore
│ │ ├── index.js # Main Cloud Functions code
│ │ └── package.json
│ ├── firebase.json # Firebase configuration
│ ├── firestore.indexes.json # Firestore indexes
│ ├── firestore.rules # Firestore security rules
│ └── storage.rules # Firebase Storage security rules
├── sightline/ # iOS application (Xcode project)
│ ├── sightline/ # Main application code
│ │ ├── Assets.xcassets/ # Asset catalog
│ │ ├── Models/ # Data models
│ │ ├── Services/ # Services for interacting with Firebase and other APIs
│ │ ├── State/ # Application state management
│ │ ├── Views/ # UI components and views
│ │ ├── sightline.xcdatamodeld/ # Core Data model (empty, not actively used)
│ │ ├── DebugGalleryView.swift # Debug view for testing landmark detection
│ │ ├── LandmarkDetection.swift # Landmark detection logic
│ │ └── sightlineApp.swift # Main application entry point
│ ├── sightline.xcodeproj/ # Xcode project file
│ └── sightlineTests/ # Unit tests
│ └── sightlineUITests/ # UI Tests
├── .gitignore # Files and folders to ignore in Git
├── .markdownlint.json # Markdown linting configuration
├── .repomixignore # Files to ignore for Repomix (currently empty)
└── repomix.config.json # Repomix configuration

## Firebase Integration

Sightline utilizes several Firebase services:

### Cloud Functions

-   **`annotateImage`**: This function is the core of the landmark detection feature. It takes an image as input, sends it to the Google Cloud Vision API, and processes the results.
    -   It authenticates users (requires sign-in).
    -   It calls the Google Cloud Vision API to detect landmarks.
    -   It fetches neighborhood data using the Google Maps Geocoding API.
    -   It updates Firestore collections:
        -   `neighborhoods`: Adds or updates neighborhood information, including detected landmarks.
        -   `users/unlocked_neighborhoods`: Tracks which neighborhoods a user has unlocked.
        -   `detectedLandmarks`: Stores a record of all detected landmarks.
    -   It returns landmark information, including name, MID (Machine ID), score, locations, and neighborhood details.

### Firestore

-   **`neighborhoods` collection**: Stores information about neighborhoods, including their boundaries, landmarks, and user-generated content.  The structure includes:
    -   `id` (DocumentID): The Google Maps Place ID of the neighborhood.
    -   `name`: The name of the neighborhood.
    -   `bounds`: Geographic bounds of the neighborhood (northeast and southwest coordinates).
    -   `landmarks`: An array of landmarks within the neighborhood (including location, MID, and name).

-   **`places` collection**:  Stores detailed information about specific places.
    -   `id`: A unique identifier for the place.
    -   `name`: The name of the place.
    -   `primaryCategory`: The main category of the place (e.g., restaurant, bar).
    -   `tags`: An array of categories the place belongs to.
    -   `rating`: The average rating of the place.
    -   `reviewCount`: The number of reviews for the place.
    -   `coordinates`: The geographical coordinates of the place.
    -   `neighborhoodId`: The ID of the neighborhood the place belongs to.
    -   `address`:  The street address of the place.
    -   `description`: A description of the place.
    -   `thumbnailUrl`: A URL to a thumbnail image of the place.
    -   `details`: A dictionary of additional details.

-   **`content` collection**: Stores user-generated content (videos, captions, etc.).
    -   `id`: A unique identifier for the content.
    -   `placeIds`:  An array of place IDs the content is associated with.
    -   `eventIds`: An array of event IDs the content is associated with (optional).
    -   `neighborhoodId`: The ID of the neighborhood the content belongs to.
    -   `authorId`: The ID of the user who created the content.
    -   `videoUrl`: The URL of the video.
    -   `thumbnailUrl`: The URL of the video thumbnail.
    -   `caption`: The caption for the video.
    -   `tags`: An array of categories the content belongs to.
    -   `likes`: The number of likes the content has received.
    -   `views`: The number of views the content has received.
    -   `createdAt`: Timestamp of when the content was created.
    -   `updatedAt`: Timestamp of when the content was last updated.

-   **`users` collection**:  Stores user-specific data.  Crucially, it contains subcollections:
    -   `users/{userId}/unlocked_neighborhoods`:  Tracks which neighborhoods a user has unlocked.  Documents are named by `neighborhoodId`, and fields include `unlocked_at`, `unlocked_by_landmark`, `landmark_mid`, and `landmark_location`.
    -   `users/{userId}/saved_places`: Tracks the places a user has saved. Documents are named by `placeId`.

- **`detectedLandmarks` collection**: A record of landmarks detected by the Vision API.

### Firebase Storage

Firebase Storage is used to store user-uploaded videos and thumbnails. The `storage.rules` file is currently set to `allow read, write: if false;`, meaning *all access is denied*.  This is a crucial security issue and needs to be addressed before deployment.  Proper rules should be implemented to control access based on authentication and authorization.

### Authentication

Sightline uses Firebase Authentication to manage user accounts. It supports:

-   **Anonymous Authentication:** Users can start using the app without creating an account.
-   **Email/Password Authentication:** Users can create accounts to save their progress and preferences.  The `ProfileView` handles sign-up, sign-in, and account reset.

## iOS Application (SwiftUI)

The iOS application is built using SwiftUI and follows a Model-View-ViewModel (MVVM) architecture.

### Models

-   **`Content`**: Represents a piece of user-generated content (video, caption, etc.).
-   **`Event`**: Represents an event happening at a specific place.  (Not fully implemented in the provided code.)
-   **`FilterCategory`**: An enum representing different content categories.
-   **`Neighborhood`**: Represents a neighborhood, including its boundaries and landmarks.
-   **`Place`**: Represents a specific place (e.g., a restaurant, park, museum).

### Services

-   **`AuthService`**: Handles user authentication (anonymous and email/password).
-   **`FirestoreService`**: Provides methods for interacting with Firestore, including fetching data, saving data, and managing user-specific information.
-   **`VideoPlayerManager`**: Manages video playback, including preloading and caching.  This is a key class for optimizing the user experience.

### State Management

-   **`AppState`**: An `ObservableObject` that holds global application state, such as navigation and whether the user should be switched to the feed.
-   **`AppViewModel`**: An `ObservableObject` that manages preloading of data on app launch.
-   **`ContentFeedViewModel`**: An `ObservableObject` that manages the content feed, including fetching content, handling neighborhood and category selections, and controlling video playback.
-   **`ContentItemViewModel`**:  An `ObservableObject` that manages individual content items within the feed, primarily loading and displaying the associated place name.
-   **`PlaceDetailViewModel`**: An `ObservableObject` that manages the Place Detail view, loading place details and handling user interactions (e.g., saving a place).
-   **`ProfileViewModel`**: An `ObservableObject` for managing the user's profile, including authentication state, saved places, and sign-out functionality.
-   **`LandmarkDetectionViewModel`**: An `ObservableObject` responsible for handling the landmark detection process, calling the Cloud Function, and processing the results.

### Views

-   **`AdaptiveColorButton`**: A reusable button component with adaptive styling.
-   **`FloatingMenuButton`**: A button component used in the floating menu.
-   **`FloatingMenu`**: A custom floating menu component for selecting neighborhoods and categories.
-   **`ScanningAnimation`**:  The animation displayed while the app is scanning for landmarks.
-   **`ScanningTransitionView`**:  The animation shown when a landmark is detected.
-   **`ContentFeedView`**: The main view that displays the content feed.
-   **`CameraView`**: The view that displays the camera feed and handles capturing images for landmark detection.
-   **`ContentItemView`**: Displays a single content item (video and caption) in the feed.
-   **`MainTabView`**: The main tab bar interface of the application.
-   **`PlaceDetailView`**: Displays detailed information about a specific place.
-   **`ProfileView`**: Displays the user's profile and authentication options.
-   **`SplashView`**: The initial splash screen displayed when the app launches.
-   **`VerticalFeedView`**: A custom view that implements vertical scrolling for the content feed using `UIPageViewController`.
-   **`DebugGalleryView`**: (DEBUG only) A view for testing landmark detection with a gallery of images.
-   **`LandmarkDetectionView`**: The main view for the landmark detection feature.
- **`LandmarkDetailView`**: (Within `LandmarkDetection.swift`) Displays detailed information about a detected landmark.

### Landmark Detection (iOS)

The `LandmarkDetectionView` and `LandmarkDetectionViewModel` handle the landmark detection process on the client-side.  The `CameraView` uses `AVCaptureSession` to capture video frames.  The `CameraController` class manages the camera session, captures images, and sends them to the `LandmarkDetectionViewModel`.  The view model then converts the image to Base64, calls the `annotateImage` Cloud Function, and processes the result.  The UI is updated based on the detection results, including animations for scanning and successful detection.

### Video Playback

The `VideoPlayerManager` class handles video playback using `AVQueuePlayer`. It prefetches and caches videos to improve performance and provide a smoother user experience. The `VerticalFeedView` uses this manager to display videos in the content feed.

## Development Setup

### Prerequisites

-   Xcode 14 or later
-   iOS 16 or later (for deployment)
-   A Firebase project
-   Node.js and npm (for Firebase Functions)
-   The Firebase CLI

### Installation

1.  **Clone the repository:**

    ```bash
    git clone <repository_url>
    cd <repository_name>
    ```

2.  **Install Firebase dependencies:**

    ```bash
    cd firebase/functions
    npm install
    ```

3.  **Install iOS dependencies:**
    *  Open the `sightline.xcodeproj` file in Xcode.
    *  Xcode should automatically resolve and fetch Swift Package dependencies.

### Configuration

1.  **Firebase:**
    -   Create a Firebase project in the Firebase console.
    -   Enable Firestore, Firebase Storage, Cloud Functions, and Firebase Authentication (Anonymous and Email/Password).
    -   Download the `GoogleService-Info.plist` file and add it to the `sightline/sightline/` directory in your Xcode project.  *Make sure it's added to the target.*
    -   Set up Firestore indexes as defined in `firebase/firestore.indexes.json`.
    -   Deploy Firestore rules (`firebase/firestore.rules`) and Storage rules (`firebase/storage.rules`). **Important:** Update the Storage rules to allow appropriate access.
    -   Deploy Cloud Functions:

        ```bash
        cd firebase/functions
        firebase deploy --only functions
        ```
    -   Set the `GOOGLE_MAPS_API_KEY` environment variable for the `annotateImage` function. You can do this in the Firebase console or using the Firebase CLI:
        ```bash
        firebase functions:config:set googlemaps.apikey="YOUR_API_KEY"
        ```
        Then redeploy the functions.

2.  **Xcode:**
    -   Open the `sightline.xcodeproj` file in Xcode.
    -   Ensure the `GoogleService-Info.plist` file is correctly added to the project.
    -   Build and run the project on a simulator or a physical device.

## Testing

-   **Unit Tests (`sightlineTests`)**:  The project includes a basic unit test file.  More comprehensive unit tests should be added to test individual components and services.
-   **UI Tests (`sightlineUITests`)**: The project includes basic UI tests, including a launch test.  More UI tests should be added to test user flows and interactions.

## Contributing

Contributions are welcome! Please follow these guidelines:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix.
3.  Make your changes and commit them with clear commit messages.
4.  Write tests for your changes.
5.  Submit a pull request.

## License

[Add your chosen license here. For example, MIT, Apache 2.0, etc.  If you don't specify a license, the code is not open source.]

## Code Overview (Repomix)

This README was significantly enhanced and expanded using Repomix, which provided a packed representation of the codebase.  The initial code provided was combined into a single, well-structured document, allowing for a comprehensive understanding of the project's structure, functionality, and dependencies. This README leverages the Repomix output to provide a clear and detailed explanation of the Sightline project.