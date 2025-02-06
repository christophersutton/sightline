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
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
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
    
    // MARK: - Test Data Population
    func populateTestData() async throws {
        // Add test content mixing restaurants and events
        let contentItems = [
            // Downtown Austin - Restaurants
            (placeId: "franklins_bbq", type: ContentType.restaurant, caption: "Best brisket in Austin! 🍖"),
            (placeId: "franklins_bbq", type: ContentType.restaurant, caption: "Worth the wait in line"),
            (placeId: "franklins_bbq", type: ContentType.restaurant, caption: "Morning line check - get here early! ⏰"),
            
            // Downtown Austin - Events
            (placeId: "franklins_bbq", type: ContentType.event, caption: "Live music on the patio! 🎸"),
            (placeId: "franklins_bbq", type: ContentType.event, caption: "BBQ masterclass this weekend"),
            
            // Butler Shores - Restaurants
            (placeId: "cosmic_coffee", type: ContentType.restaurant, caption: "Perfect morning coffee ☕️"),
            (placeId: "cosmic_coffee", type: ContentType.restaurant, caption: "Beer garden vibes 🍺"),
            (placeId: "cosmic_coffee", type: ContentType.restaurant, caption: "Food truck heaven!"),
            
            // Butler Shores - Events
            (placeId: "cosmic_coffee", type: ContentType.event, caption: "Live music night! 🎸"),
            (placeId: "cosmic_coffee", type: ContentType.event, caption: "Sunday morning yoga in the garden 🧘‍♀️"),
            (placeId: "cosmic_coffee", type: ContentType.event, caption: "Local artist showcase tonight!")
        ]
        
        // Add more video URLs to cycle through
        let videoUrls = [
            "gs://sightline-app-gauntlet.firebasestorage.app/vid1.mp4",
            "gs://sightline-app-gauntlet.firebasestorage.app/vid2.mp4",
            "gs://sightline-app-gauntlet.firebasestorage.app/vid3.mp4",
            "gs://sightline-app-gauntlet.firebasestorage.app/vid1.mp4",  // Reuse videos for now
            "gs://sightline-app-gauntlet.firebasestorage.app/vid2.mp4",
            "gs://sightline-app-gauntlet.firebasestorage.app/vid3.mp4"
        ]
        
        // Add our two test neighborhoods
        let neighborhoods = [
            [
                "place_id": "downtown_austin",
                "name": "Downtown Austin",
                "bounds": [
                    "northeast": GeoPoint(latitude: 30.2849, longitude: -97.7341),
                    "southwest": GeoPoint(latitude: 30.2610, longitude: -97.7501)
                ]
            ],
            [
                "place_id": "butler_shores",
                "name": "Butler Shores",
                "bounds": [
                    "northeast": GeoPoint(latitude: 30.2670, longitude: -97.7550),
                    "southwest": GeoPoint(latitude: 30.2610, longitude: -97.7650)
                ]
            ]
        ]
        
        for neighborhood in neighborhoods {
            try await db.collection("neighborhoods")
                .document(neighborhood["place_id"] as! String)
                .setData(neighborhood)
        }
        
        // Update places with restaurants
        let places = [
            Place(
                id: "franklins_bbq",
                name: "Franklin Barbecue",
                category: "restaurant",
                rating: 4.8,
                reviewCount: 342,
                coordinates: GeoPoint(latitude: 30.2701, longitude: -97.7313),
                neighborhoodId: "downtown_austin",
                address: "900 E 11th St, Austin, TX 78702",
                thumbnailUrl: nil,
                details: ["cuisine": "BBQ", "priceRange": "$$"],
                tags: ["restaurant", "bbq", "lunch"],
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            ),
            Place(
                id: "cosmic_coffee",
                name: "Cosmic Coffee + Beer Garden",
                category: "restaurant",
                rating: 4.7,
                reviewCount: 234,
                coordinates: GeoPoint(latitude: 30.2456, longitude: -97.7644),
                neighborhoodId: "butler_shores",
                address: "121 Pickle Rd, Austin, TX 78704",
                thumbnailUrl: nil,
                details: ["cuisine": "Coffee Shop", "priceRange": "$$"],
                tags: ["restaurant", "coffee", "beer"],
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )
        ]
        
        for place in places {
            try await addPlace(place)
        }
        
        // Distribute our 3 videos across the content items
        for (index, item) in contentItems.enumerated() {
            let content = Content(
                id: "content_\(index)",
                placeId: item.placeId,
                authorId: "test_author",
                type: item.type,
                videoUrl: videoUrls[index % videoUrls.count],
                thumbnailUrl: "",
                caption: item.caption,
                tags: ["austin", "local"],
                likes: Int.random(in: 10...100),
                views: Int.random(in: 100...1000),
                neighborhoodId: item.placeId == "franklins_bbq" ? "downtown_austin" : "butler_shores",
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )
            
            try await addContent(content)
        }
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
    
    func saveDetectionResult(landmarkName: String) async throws {
        let landmarkData: [String: Any] = [
            "name": landmarkName,
            "detectedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("detectedLandmarks")
            .addDocument(data: landmarkData)
    }
    
    func unlockTestNeighborhood(for userId: String) async throws {
        // Unlock downtown_austin by default
        try await db.collection("users")
            .document(userId)
            .collection("unlocked_neighborhoods")
            .document("downtown_austin")
            .setData([
                "unlocked_at": FieldValue.serverTimestamp(),
                "unlocked_by_landmark": "Test Data",
                "landmark_location": GeoPoint(
                    latitude: 30.2672,
                    longitude: -97.7431
                )
            ])
    }
    
    func deleteAllTestData() async throws {
        // Delete content
        let contentSnapshot = try await db.collection("content").getDocuments()
        for doc in contentSnapshot.documents {
            try await doc.reference.delete()
        }
        
        // Delete places
        let placesSnapshot = try await db.collection("places").getDocuments()
        for doc in placesSnapshot.documents {
            try await doc.reference.delete()
        }
        
        // Delete neighborhoods
        let neighborhoodsSnapshot = try await db.collection("neighborhoods").getDocuments()
        for doc in neighborhoodsSnapshot.documents {
            try await doc.reference.delete()
        }
        
        // Delete unlocked neighborhoods for all users
        if let userId = Auth.auth().currentUser?.uid {
            let unlockedSnapshot = try await db.collection("users")
                .document(userId)
                .collection("unlocked_neighborhoods")
                .getDocuments()
            for doc in unlockedSnapshot.documents {
                try await doc.reference.delete()
            }
        }
    }
}