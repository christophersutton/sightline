import FirebaseFirestore
import FirebaseStorage
import AVKit
import FirebaseAuth

protocol FirestoreServiceProtocol {
    // Neighborhoods
//    func unlockNeighborhood(userId: String, landmark: LandmarkInfo) async throws
    func fetchUnlockedNeighborhoods(for userId: String) async throws -> [Neighborhood]
    
    // Test Data
    func populateTestData() async throws
    func unlockTestNeighborhood(for userId: String) async throws
    func deleteAllTestData() async throws
    
    // Content
    func fetchContentForPlace(placeId: String) async throws -> [Content]
    func fetchContentByCategory(category: String) async throws -> [Content]
    func fetchContentByCategory(category: ContentType, neighborhoodId: String) async throws -> [Content]
    
    // Detection
    func saveDetectionResult(landmarkName: String) async throws
    
    // Places
    func fetchPlace(id: String) async throws -> Place
    func fetchPlacesInNeighborhood(neighborhoodId: String) async throws -> [Place]
    func addPlace(_ place: Place) async throws
}

class FirestoreService: FirestoreServiceProtocol {
    let db = Firestore.firestore()
    let storage = Storage.storage()
    
    // MARK: - Places
    func fetchPlacesInNeighborhood(neighborhoodId: String) async throws -> [Place] {
        let query = db.collection("places").whereField("neighborhoodId", isEqualTo: neighborhoodId)
        let snapshot = try await query.getDocuments()
            
        return try snapshot.documents.map { try $0.data(as: Place.self) }
    }
    
    func addPlace(_ place: Place) async throws {
        try await db.collection("places")
            .document(place.id)
            .setData(from: place)
    }
    
    func fetchPlace(id: String) async throws -> Place {
        let docRef = db.collection("places").document(id)
        let document = try await docRef.getDocument()
        return try document.data(as: Place.self)
    }
    
    // MARK: - Content
    func fetchContentForPlace(placeId: String) async throws -> [Content] {
        let snapshot = try await db.collection("content")
            .whereField("placeId", isEqualTo: placeId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            try? document.data(as: Content.self)
        }
    }
    
    func addContent(_ content: Content) async throws {
        try await db.collection("content")
            .document(content.id)
            .setData(from: content)
    }
    
    func fetchContentByCategory(category: String) async throws -> [Content] {
        let snapshot = try await db.collection("content")
            .whereField("type", isEqualTo: category)
            .order(by: "createdAt", descending: true)
            .limit(to: 5) // Start with a small batch
            .getDocuments()
            
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Content.self)
        }
    }
    
    func fetchContentByCategory(category: ContentType, neighborhoodId: String) async throws -> [Content] {
        print("🔍 Fetching content for neighborhood: \(neighborhoodId), category: \(category.rawValue)")
        
        let query = db.collection("content")
            .whereField("neighborhoodId", isEqualTo: neighborhoodId)
            .whereField("type", isEqualTo: category.rawValue)
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        
        let content = snapshot.documents.compactMap { document -> Content? in
            guard let content = try? document.data(as: Content.self) else {
                print("⚠️ Failed to decode content: \(document.documentID)")
                return nil
            }
            return content
        }
        
        print("✅ Found \(content.count) content items")
        return content
    }


    func saveDetectionResult(landmarkName: String) async throws {
        let landmarkData: [String: Any] = [
            "name": landmarkName,
            "detectedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("detectedLandmarks")
            .addDocument(data: landmarkData)
    }
    
    func fetchUnlockedNeighborhoods(for userId: String) async throws -> [Neighborhood] {
        print("🔍 Fetching unlocked neighborhoods for user: \(userId)")
        
        // Get the unlocked neighborhoods from the user's subcollection
        let unlockedSnapshot = try await db.collection("users")
            .document(userId)
            .collection("unlocked_neighborhoods")
            .getDocuments()
        
        // Use the document IDs as the neighborhood IDs
        let neighborhoodIds = unlockedSnapshot.documents.map { $0.documentID }
        
        guard !neighborhoodIds.isEmpty else {
            print("⚠️ No unlocked neighborhoods found for user")
            return []
        }
        
        // Then fetch the actual neighborhoods from the neighborhoods collection
        let neighborhoodSnapshot = try await db.collection("neighborhoods")
            .whereField(FieldPath.documentID(), in: neighborhoodIds)
            .getDocuments()
        
        let neighborhoods = neighborhoodSnapshot.documents.compactMap { document -> Neighborhood? in
            do {
                // Get the raw data
                let data = document.data()
                
                // Manually construct the Neighborhood
                return Neighborhood(
                    id: document.documentID,
                    name: data["name"] as? String ?? "",
                    bounds: try decodeGeoBounds(from: data["bounds"] as? [String: Any] ?? [:]),
                    landmarks: try decodeLandmarks(from: data["landmarks"] as? [[String: Any]] ?? [])
                )
            } catch {
                print("⚠️ Failed to decode neighborhood: \(document.documentID)")
                // Convert document data to a debug-friendly format
                let data = document.data()
                var debugData: [String: Any] = [:]
                
                // Handle special cases like GeoPoint
                for (key, value) in data {
                    if let geoPoint = value as? GeoPoint {
                        debugData[key] = ["lat": geoPoint.latitude, "lng": geoPoint.longitude]
                    } else if let array = value as? [[String: Any]] {
                        // Handle arrays that might contain GeoPoints
                        debugData[key] = array.map { item in
                            var newItem = item
                            for (k, v) in item {
                                if let gp = v as? GeoPoint {
                                    newItem[k] = ["lat": gp.latitude, "lng": gp.longitude]
                                }
                            }
                            return newItem
                        }
                    } else {
                        debugData[key] = value
                    }
                }
                
                print("📄 Document data:", debugData)
                print("💥 Decode error: \(error)")
                return nil
            }
        }
        
        print("✅ Found \(neighborhoods.count) unlocked neighborhoods")
        return neighborhoods
    }
    
//    func fetchPlace(id: String) async throws -> Place {
//        let snapshot = try await db.collection("places").document(id).getDocument()
//        guard let place = try? snapshot.data(as: Place.self) else {
//            throw FirestoreError.decodingError
//        }
//        return place
//    }
} 
//    func unlockNeighborhood(userId: String, landmark: LandmarkInfo) async throws {
//        guard let neighborhood = landmark.neighborhood else {
//            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No neighborhood found"])
//        }
//        
//        try await db.collection("users")
//            .document(userId)
//            .collection("unlocked_neighborhoods")
//            .document(neighborhood.id)
//            .setData([
//                "unlocked_at": FieldValue.serverTimestamp(),
//                "unlocked_by_landmark": landmark.name,
//                "landmark_location": GeoPoint(
//                    latitude: landmark.latitude ?? 0,
//                    longitude: landmark.longitude ?? 0
//                )
//            ])
//    }
    
    // Helper function to decode GeoBounds
    private func decodeGeoBounds(from data: [String: Any]) throws -> Neighborhood.GeoBounds {
        guard let northeast = data["northeast"] as? [String: Any],
              let southwest = data["southwest"] as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing bounds data"))
        }
        
        return Neighborhood.GeoBounds(
            northeast: .init(
                lat: northeast["lat"] as? Double ?? 0,
                lng: northeast["lng"] as? Double ?? 0
            ),
            southwest: .init(
                lat: southwest["lat"] as? Double ?? 0,
                lng: southwest["lng"] as? Double ?? 0
            )
        )
    }
    
    // Helper function to decode Landmarks
    private func decodeLandmarks(from data: [[String: Any]]) throws -> [Neighborhood.Landmark]? {
        return data.compactMap { landmarkData in
            guard let location = landmarkData["location"] as? GeoPoint,
                  let mid = landmarkData["mid"] as? String,
                  let name = landmarkData["name"] as? String else {
                return nil
            }
            
            return Neighborhood.Landmark(
                location: location,
                mid: mid,
                name: name
            )
        }
    }

