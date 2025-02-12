import FirebaseFirestore
import FirebaseStorage
import AVKit
import FirebaseAuth

protocol FirestoreServiceProtocol {
    // Neighborhoods
    func fetchUnlockedNeighborhoods(for userId: String) async throws -> [Neighborhood]
    
    // Test Data
//    func populateTestData() async throws
//    func deleteAllTestData() async throws
    
    // Content
    func fetchContentForPlace(placeId: String) async throws -> [Content]
    func fetchContentByCategory(category: FilterCategory, neighborhoodId: String?) async throws -> [Content]
    func saveDetectionResult(landmarkName: String) async throws
    
    // Places
    func fetchPlace(id: String) async throws -> Place
    func fetchPlacesInNeighborhood(neighborhoodId: String) async throws -> [Place]
    func addPlace(_ place: Place) async throws
    func fetchAvailableCategories(for neighborhoodId: String) async throws -> [FilterCategory]
    
    // New for saving places
    func savePlaceForUser(userId: String, placeId: String) async throws
    func fetchSavedPlaceIds(for userId: String) async throws -> [String]
    func removeSavedPlace(userId: String, placeId: String) async throws
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

    func fetchAvailableCategories(for neighborhoodId: String) async throws -> [FilterCategory] {
        print("🔍 Fetching available categories for neighborhood: \(neighborhoodId)")
        
        let snapshot = try await db.collection("content")
            .whereField("neighborhoodId", isEqualTo: neighborhoodId)
            .getDocuments()
        
        // Create a Set to store unique categories
        var categorySet = Set<String>()
        
        // Collect all unique categories from content
        for document in snapshot.documents {
            if let tags = document.data()["tags"] as? [String] {
                categorySet.formUnion(tags)
            }
        }
        
        // Convert strings to FilterCategory and filter out invalid ones
        let categories = categorySet.compactMap { tagString -> FilterCategory? in
            return FilterCategory(rawValue: tagString)
        }.sorted { $0.rawValue < $1.rawValue }
        
        print("✅ Found \(categories.count) available categories")
        return categories
    }
    
    // MARK: - User Places (new)
    
    /// Save a place under the user's saved_places subcollection
    func savePlaceForUser(userId: String, placeId: String) async throws {
        let docRef = db.collection("users")
            .document(userId)
            .collection("saved_places")
            .document(placeId)
        
        try await docRef.setData([
            "savedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Fetch only the IDs of saved places; we can fetch full docs separately
    func fetchSavedPlaceIds(for userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("saved_places")
            .getDocuments()
        
        return snapshot.documents.map { $0.documentID }
    }

    func createAnnotationRequest(imageURL: String, originalFilename: String) async throws {
        let annotationRequest = [
            "imageURL": imageURL,
            "originalFilename": originalFilename,
            "status": "pending",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp()
        ] as [String : Any]
        
        try await db.collection("annotationRequests").addDocument(data: annotationRequest)
    }

    func removeSavedPlace(userId: String, placeId: String) async throws {
        let docRef = db.collection("users")
            .document(userId)
            .collection("saved_places")
            .document(placeId)
        
        try await docRef.delete()
    }
}
