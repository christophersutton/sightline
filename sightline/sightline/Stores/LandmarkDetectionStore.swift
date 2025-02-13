//
//  LandmarkDetectionStore.swift
//  sightline
//
//  Created by Chris Sutton on 2/13/25.
//


// sightline/sightline/Stores/LandmarkDetectionStore.swift
import SwiftUI
import Combine

@MainActor
class LandmarkDetectionStore: Store {
    @Published var detectedLandmark: LandmarkInfo? = nil
    @Published var errorMessage: String = ""
    @Published var debugImages: [String] = ["utcapitol1", "utcapitol2", "ladybirdlake1"]
    @Published var isCapturing = false

    private var consecutiveFailures = 0
    private let maxFailuresBeforeNotice = 3
    private var hasDetectedLandmark = false

    func startCapture() {
        isCapturing = true
        errorMessage = "Scanning..."
        consecutiveFailures = 0
        hasDetectedLandmark = false
    }

    func captureCompleted() {
        isCapturing = false
        if detectedLandmark == nil {
            errorMessage = "None detected, try finding another landmark."
        }
    }

    func reset() {
        isCapturing = false
        errorMessage = ""
        detectedLandmark = nil
        consecutiveFailures = 0
        hasDetectedLandmark = false
    }

     func detectLandmark(image: UIImage, using service: LandmarkDetectionService) async {
        guard !hasDetectedLandmark else { return }

        self.detectedLandmark = nil
        do {
            if let landmarkData = try await service.detectLandmark(in: image) {
                hasDetectedLandmark = true
                consecutiveFailures = 0
                let name = (landmarkData["name"] as? String) ?? "Unknown"
                let locations = (landmarkData["locations"] as? [[String: Any]]) ?? []
                var lat: Double? = nil
                var lon: Double? = nil
                if let firstLocation = locations.first,
                   let latLng = firstLocation["latLng"] as? [String: Any] {
                    lat = latLng["latitude"] as? Double
                    lon = latLng["longitude"] as? Double
                }
                let nbData = landmarkData["neighborhood"] as? [String: Any]
                let neighborhood = buildNeighborhood(from: nbData)
                let landmarkInfo = LandmarkInfo(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    neighborhood: neighborhood
                )
                self.detectedLandmark = landmarkInfo
                self.errorMessage = ""
                consecutiveFailures = 0
            } else {
                consecutiveFailures += 1
                if consecutiveFailures >= maxFailuresBeforeNotice && isCapturing {
                    self.errorMessage = "No landmarks detected yet... Keep scanning the area"
                }
            }
        } catch {
            consecutiveFailures += 1
            if consecutiveFailures >= maxFailuresBeforeNotice && isCapturing {
                self.errorMessage = "Having trouble detecting landmarks. Try moving closer or adjusting your angle."
            } else {
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func buildNeighborhood(from data: [String: Any]?) -> Neighborhood? {
        guard let data = data,
              let placeId = data["place_id"] as? String,
              let nbName = data["name"] as? String,
              let geometry = data["bounds"] as? [String: Any],
              let ne = geometry["northeast"] as? [String: Any],
              let sw = geometry["southwest"] as? [String: Any] else {
            return nil
        }
        let bounds = Neighborhood.GeoBounds(
            northeast: Neighborhood.GeoBounds.Point(
                lat: ne["lat"] as? Double ?? 0,
                lng: ne["lng"] as? Double ?? 0
            ),
            southwest: Neighborhood.GeoBounds.Point(
                lat: sw["lat"] as? Double ?? 0,
                lng: sw["lng"] as? Double ?? 0
            )
        )
        return Neighborhood(
            id: placeId,
            name: nbName,
            description: nil,
            imageUrl: nil,
            bounds: bounds,
            landmarks: nil
        )
    }

}
