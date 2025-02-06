import FirebaseFirestore
import FirebaseStorage
import AVKit
import FirebaseAuth

protocol FirestoreServiceProtocol {
    // Neighborhoods
    func unlockNeighborhood(userId: String, landmark: LandmarkInfo) async throws
    func fetchUnlockedNeighborhoods(for userId: String) async throws -> [Neighborhood]
    
    // Test Data
    func populateTestData() async throws
    func unlockTestNeighborhood(for userId: String) async throws
    func deleteAllTestData() async throws
    
    // Content
    func fetchContentForPlace(placeId: String) async throws -> [Content]
    func fetchContentByCategory(category: String) async throws -> [Content]
    func fetchContentByCategory(category: ContentType, neighborhoodId: String) async throws -> [Content]
    
    // Places
    func fetchPlace(id: String) async throws -> Place
    
    // Detection
    func saveDetectionResult(landmarkName: String) async throws
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
            
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Content.self)
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
        
        // First get the unlocked neighborhood IDs
        let unlockedSnapshot = try await db.collection("user_neighborhoods")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let neighborhoodIds = unlockedSnapshot.documents.compactMap { document -> String? in
            let data = document.data()
            return data["neighborhoodId"] as? String
        }
        
        guard !neighborhoodIds.isEmpty else {
            print("⚠️ No unlocked neighborhoods found for user")
            return []
        }
        
        // Then fetch the actual neighborhoods
        let neighborhoodSnapshot = try await db.collection("neighborhoods")
            .whereField(FieldPath.documentID(), in: neighborhoodIds)
            .getDocuments()
        
        let neighborhoods = neighborhoodSnapshot.documents.compactMap { document -> Neighborhood? in
            guard let neighborhood = try? document.data(as: Neighborhood.self) else {
                print("⚠️ Failed to decode neighborhood: \(document.documentID)")
                return nil
            }
            return neighborhood
        }
        
        print("✅ Found \(neighborhoods.count) unlocked neighborhoods")
        return neighborhoods
    }
    
    func unlockNeighborhood(userId: String, landmark: LandmarkInfo) async throws {
        guard let neighborhood = landmark.neighborhood else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No neighborhood found"])
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("unlocked_neighborhoods")
            .document(neighborhood.id)
            .setData([
                "unlocked_at": FieldValue.serverTimestamp(),
                "unlocked_by_landmark": landmark.name,
                "landmark_location": GeoPoint(
                    latitude: landmark.latitude ?? 0,
                    longitude: landmark.longitude ?? 0
                )
            ])
    }
}
