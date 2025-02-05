import FirebaseFirestore
import FirebaseStorage
import AVKit

protocol FirestoreServiceProtocol {
    // Neighborhoods
    func unlockNeighborhood(userId: String, landmark: LandmarkInfo) async throws
    func fetchUnlockedNeighborhoods(for userId: String) async throws -> [Neighborhood]
    
    // Test Data
    func populateTestData() async throws
    
    // Content
    func fetchContentForPlace(placeId: String) async throws -> [Content]
    func fetchContentByCategory(category: String) async throws -> [Content]
    
    // Detection
    func saveDetectionResult(landmarkName: String) async throws
}

class FirestoreService: FirestoreServiceProtocol {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Places
    func fetchPlacesInNeighborhood(neighborhoodId: String) async throws -> [Place] {
        let snapshot = try await db.collection("places")
            .whereField("neighborhoodId", isEqualTo: neighborhoodId)
            .getDocuments()
            
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Place.self)
        }
    }
    
    func addPlace(_ place: Place) async throws {
        try await db.collection("places")
            .document(place.id)
            .setData(from: place)
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
            
        let contents = snapshot.documents.compactMap { doc in
            try? doc.data(as: Content.self)
        }
        
        // Start preloading videos
        Task {
            await preloadVideos(for: contents)
        }
        
        return contents
    }
    
    private func preloadVideos(for contents: [Content]) async {
        for content in contents {
            guard let url = URL(string: content.videoUrl) else { continue }
            
            let asset = AVURLAsset(url: url)
            
            do {
                _ = try await asset.load(.isPlayable)
            } catch {
                print("Error preloading video: \(error)")
            }
        }
    }
    
    // MARK: - Test Data Population
    func populateTestData() async throws {
        let videoUrls = [
            "gs://sightline-app-gauntlet.firebasestorage.app/vid1.mp4",
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
        
        // Add test content mixing restaurants and events
        let contentItems = [
            (placeId: "franklins_bbq", category: "restaurant", caption: "Best brisket in Austin! 🍖"),
            (placeId: "franklins_bbq", category: "restaurant", caption: "Worth the wait in line"),
            (placeId: "cosmic_coffee", category: "event", caption: "Live music night! 🎸"),
        ]
        
        // Distribute our 3 videos across the content items
        for (index, item) in contentItems.enumerated() {
            let content = Content(
                id: "content_\(index)",
                placeId: item.placeId,
                authorId: "test_author",
                type: .highlight,
                videoUrl: videoUrls[index % videoUrls.count],
                thumbnailUrl: "", // We can add these later if needed
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
    
    func fetchUnlockedNeighborhoods(for uid: String) async throws -> [Neighborhood] {
        let snapshot = try await db.collection("users")
            .document(uid)
            .collection("unlocked_neighborhoods")
            .getDocuments()
            
        var neighborhoods: [Neighborhood] = []
        
        for doc in snapshot.documents {
            do {
                let neighborhoodDoc = try await db.collection("neighborhoods")
                    .document(doc.documentID)
                    .getDocument()
                
                guard let data = neighborhoodDoc.data() else { continue }
                neighborhoods.append(Neighborhood(from: data))
            } catch {
                print("Error fetching neighborhood \(doc.documentID): \(error)")
                continue
            }
        }
        
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
} 