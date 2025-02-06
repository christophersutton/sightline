# Refactoring and Improved Detection Handling Plan

This document outlines a step-by-step plan to refactor the current landmark detection codebase and improve detection handling. You will end up with a modular codebase where camera frames are pre-processed using on-device analysis (e.g., Vision APIs) to only send stable and unique frames for network processing. This guide is thorough enough for a junior developer to follow and begin implementation.

---

## Table of Contents

1. [Overview](#overview)
2. [Goals](#goals)
3. [Directory Structure and Module Breakdown](#directory-structure-and-module-breakdown)
4. [Step-by-Step Refactoring Plan](#step-by-step-refactoring-plan)
5. [Improving Detection Handling](#improving-detection-handling)
6. [Integration and Testing](#integration-and-testing)
7. [Additional Tips](#additional-tips)

---

## Overview

The current implementation involves a monolithic landmark detection that sends a network request every second. Our objective is twofold:

1. **Refactor the code** to separate concerns (models, networking, view model, and UI) so it’s easier to maintain and extend.
2. **Improve detection handling** by using on-device image processing (e.g., via Vision APIs) to determine when to send a network request. This will reduce unnecessary requests while ensuring a smooth user experience—users simply hold up the camera, and the app intelligently scans and detects landmarks.

---

## Goals

- **Modularization:**  
  Separate domain models, view models, networking logic, image processing, and UI components into distinct files and directories.

- **Task Management & Cancellation:**  
  Introduce explicit task handles in the view model so that in-flight network requests can be cancelled when a new frame qualifies.

- **On-Device Preprocessing:**  
  Use Vision APIs or similar techniques to detect motion, focus, and frame uniqueness. Only send frames that are stable and different from previous ones.

- **Smooth User Experience:**  
  Ensure the user can hold up the camera and have the landmark detected without manual intervention, with visual cues to indicate processing.

---

## Directory Structure and Module Breakdown

Create a directory structure that separates the responsibilities:

- **Models:**  
  Contains domain models and data structures.  
  - `/Models/LandmarkInfo.swift`  
  - `/Models/Neighborhood.swift`  
  - `/Models/GeoBounds.swift`

- **ViewModels:**  
  Contains the logic for handling state and coordinating tasks.  
  - `/ViewModels/LandmarkDetectionViewModel.swift`

- **Services:**  
  Contains networking and image processing logic.  
  - `/Services/DetectionService.swift` (handles Firebase calls)  
  - `/Services/ImageProcessingManager.swift` (handles Vision API integration)

- **Views:**  
  Contains all SwiftUI views and UI components.  
  - `/Views/LandmarkDetectionView.swift`  
  - `/Views/CameraView.swift`  
  - `/Views/ScanningTransitionView.swift`  
  - `/Views/ScanningAnimation.swift`

---

## Step-by-Step Refactoring Plan

### 1. Separate Domain Models

Move your data structures into the `/Models` directory. For example, create a file called `LandmarkInfo.swift`:

<code>
struct LandmarkInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
    let detailedDescription: String?
    let websiteUrl: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let neighborhood: Neighborhood?

    // Initialization logic as required
}
</code>

Similarly, place `Neighborhood` and any other related models into their own files.

### 2. Isolate the View Model

Extract the logic for handling landmark detection and task management into `/ViewModels/LandmarkDetectionViewModel.swift`. Explicitly manage cancellation tokens, like so:

<code>
class LandmarkDetectionViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var detectionResult: String = ""
    @Published var detectedLandmark: LandmarkInfo?
    @Published var unlockStatus: String = ""
    @Published var isLoading = false

    private var detectionTask: Task<Void, Never>? = nil

    // Inject dependencies (e.g., detectionService, imageProcessingManager)
    private let detectionService = DetectionService.shared
    private let imageProcessingManager = ImageProcessingManager.shared

    // Start detection, cancelling any existing task
    func startDetection(for image: UIImage) {
        detectionTask?.cancel()
        detectionTask = Task {
            await detectLandmark(for: image)
        }
    }

    // Cancellation method
    func cancelDetection() {
        detectionTask?.cancel()
        detectionTask = nil
    }

    func detectLandmark(for image: UIImage) async {
        await MainActor.run {
            isLoading = true
            detectionResult = ""
            detectedLandmark = nil
        }

        // Processing logic goes here
        // Use detectionService to call Firebase detection,
        // and check periodically for Task.isCancelled to exit early
        // ...
        
        await MainActor.run {
            isLoading = false
        }
    }
}
</code>

### 3. Create the Detection Service

Encapsulate all Firebase networking calls in `/Services/DetectionService.swift`. This file acts as the single point for making and cancelling network requests:

<code>
class DetectionService {
    static let shared = DetectionService()

    private lazy var functions = Functions.functions()

    // Function to call Firebase cloud function for detection
    func annotateImage(with requestData: [String: Any]) async throws -> [String: Any]? {
        let result = try await functions.httpsCallable("annotateImage").call(requestData)
        return result.data as? [String: Any]
    }
}
</code>

### 4. Implement the Image Processing Manager

Place logic for image analysis in `/Services/ImageProcessingManager.swift`. This manager uses Vision APIs to decide if a frame is “stable” or unique:

<code>
class ImageProcessingManager {
    static let shared = ImageProcessingManager()

    // Example function that compares current frame with previous one
    func frameIsStable(currentImage: UIImage, previousImage: UIImage?) -> Bool {
        // Implement Vision analysis, focus detection, and frame similarity.
        // Return true if the frame is steady and distinct.
        return true // Placeholder logic.
    }
}
</code>

### 5. Update UI Components

Split the UI code into separate files under `/Views`. For example, `LandmarkDetectionView.swift` serves as the container view:

<code>
struct LandmarkDetectionView: View {
    @StateObject private var viewModel = LandmarkDetectionViewModel()
    @State private var isCameraMode = true

    var body: some View {
        NavigationView {
            // Contains your CameraView, scanning animations, etc.
            if isCameraMode {
                CameraView(onFrameCaptured: { image in
                    // Use the image processing manager to decide if this frame should be processed.
                    if viewModel.imageProcessingManager.frameIsStable(currentImage: image, previousImage: nil) {
                        viewModel.startDetection(for: image)
                    }
                })
            } else {
                // Gallery or other view mode
            }
        }
        .onDisappear {
            viewModel.cancelDetection()
        }
    }
}
</code>

---

## Improving Detection Handling

### 1. Integrate On-Device Preprocessing

- **Vision API Integration:**  
  Use Vision APIs to process a frame. Check for:
  - **Motion:** Are consecutive frames showing too much change?
  - **Focus:** Is the image in clear focus?
  - **Uniqueness:** Compare a frame’s histogram or fingerprint with the previous frame.

- **Example Pseudocode:**  
  (This code is only a guideline and must be adapted to your app's needs.)

<code>
func analyzeFrame(image: UIImage) -> Bool {
    // 1. Run Vision request to check for focus and quality.
    // 2. Compare against a saved version of the last processed image.
    // 3. Return true only if the frame is stable and unique.
    return true
}
</code>

### 2. Debounce and Throttle Network Requests

- **Debounce Logic:**  
  Implement a short delay mechanism after a detection is triggered so that you don’t fire off multiple network requests rapidly.  
  For example, wait 0.5 to 1 second before processing the next valid frame.

- **Task Cancellation:**  
  Ensure that any in-flight detection tasks are cancelled if a new valid frame is captured or if the view disappears.

### 3. Pipeline Overview

1. **Frame Capture:**  
   The `CameraView` continuously streams frames.
2. **Local Analysis:**  
   The `ImageProcessingManager` evaluates focus, motion, and uniqueness.
3. **Trigger Network Request:**  
   If the current frame is stable, the view model calls `DetectionService` to handle network detection.
4. **Cancellation:**  
   Use explicit task handles in the view model to cancel past requests if a new valid frame qualifies.

---

## Integration and Testing

- **Step-wise Integration:**  
  Begin by separating the modules as described. Test each part independently:
  - Ensure your models load correctly.
  - Test the detection service with dummy requests.
  - Validate that the image processing manager correctly identifies stable frames.
  - Integrate these parts in the view model and then complete the UI integration.
  
- **UI Feedback:**  
  Add visual cues (e.g., a focus reticle or scanning animation) to indicate when a stable frame is detected and submitted.

- **Debugging:**  
  Log key events such as:
  - When a frame is rejected (due to instability).
  - When a frame qualifies for submission.
  - When network tasks are cancelled.
  
  This will help in tuning thresholds for focus, motion, and frame uniqueness.

---

## Additional Tips

- **Dependency Injection:**  
  Where possible, inject dependencies (like service instances) into the view model. This enables easier testing and future swapping of implementations.

- **Comment Your Code:**  
  As you refactor, add clear comments explaining the purpose of each module and function. This is invaluable for future maintainers or junior developers.

- **Iterate in Small Steps:**  
  Commit and test each module individually. Start with a minimal working refactor before integrating Vision-based detection.

- **Keep Configuration Simple:**  
  Early on, define constant thresholds for frame stability. These can later be exposed as configurable parameters or refined through analytics.

- **User Experience Focus:**  
  Even though this is a prototype, design with the user in mind. A responsive, fluid experience will make iterative testing easier.

---

By following this plan, you will have refactored code that is cleaner, modular, and ready for the integration of advanced image processing logic. This will not only help in reducing unnecessary network calls but also ensure that the overall user experience remains seamless as you iterate on the prototype.