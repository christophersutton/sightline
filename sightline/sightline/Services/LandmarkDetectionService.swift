import UIKit
import FirebaseFunctions
import FirebaseAuth
import os

/// A service that handles landmark detection by calling the Firebase Cloud Function.
actor LandmarkDetectionService {
    private lazy var functions = Functions.functions()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Sightline",
        category: "LandmarkDetection"
    )

    /// Calls the Firebase Cloud Function to detect a landmark in the given image.
    /// - Parameter image: The UIImage to analyze.
    /// - Returns: A dictionary describing the landmark, or `nil` if none found.
    func detectLandmark(in image: UIImage) async throws -> [String: Any]? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to convert image to JPEG data")
            throw LandmarkDetectionError.invalidImageData
        }
        
        let imageSize = image.size
        logger.info("Sending landmark detection request - Image size: \(imageSize.width)x\(imageSize.height), Data size: \(imageData.count) bytes")
        
        let base64String = imageData.base64EncodedString()
        let requestData: [String: Any] = [
            "image": ["content": base64String],
            "features": [
                ["maxResults": 1, "type": "LANDMARK_DETECTION"]
            ]
        ]

        logger.debug("Calling annotateImage cloud function...")
        let result = try await functions.httpsCallable("annotateImage").call(requestData)
        
        guard let dict = result.data as? [String: Any] else {
            logger.error("Invalid response format from cloud function")
            throw LandmarkDetectionError.failedCloudFunction("Invalid response format")
        }
        
        if let landmarkData = dict["landmark"] as? [String: Any] {
            if let name = landmarkData["name"] as? String {
                logger.info("Successfully detected landmark: \(name)")
            } else {
                logger.info("Successfully detected landmark (name not available)")
            }
            return landmarkData
        } else {
            logger.notice("No landmark detected in image")
            return nil
        }
    }
}

/// Errors that can occur during landmark detection.
enum LandmarkDetectionError: Error {
    case invalidImageData
    case failedCloudFunction(String)
}