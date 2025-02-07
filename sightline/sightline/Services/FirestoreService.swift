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
    func deleteAllTestData() async throws
    
    // Content
    func fetchContentForPlace(placeId: String) async throws -> [Content]
    func fetchContentByCategory(category: FilterCategory, neighborhoodId: String?) async throws -> [Content]
    
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
        try db.collection("places")
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
        try db.collection("content")
            .document(content.id)
            .setData(from: content)
    }
      
    func fetchContentByCategory(category: FilterCategory, neighborhoodId: String?) async throws -> [Content] {
        print("🔍 Fetching content for category: \(category.rawValue), neighborhood: \(neighborhoodId ?? "all")")
        
        var query = db.collection("content")
            .whereField("tags", arrayContains: category.rawValue)
            .order(by: "createdAt", descending: true)
        
        if let neighborhoodId = neighborhoodId {
            query = query.whereField("neighborhoodId", isEqualTo: neighborhoodId)
        }
        
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
            try? document.data(as: Neighborhood.self)
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

