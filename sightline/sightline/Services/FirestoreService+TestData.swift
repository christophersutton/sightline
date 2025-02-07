#if DEBUG
import FirebaseFirestore
import FirebaseAuth

extension FirestoreService {
  // MARK: - Test Data Population
  func populateTestData() async throws {
    // First create our places
    let places = [
      Place(
        id: "caroline_restaurant",
        name: "Caroline",
        primaryCategory: .restaurant,
        tags: [.restaurant, .drinks],
        rating: 4.6,
        reviewCount: 285,
        coordinates: GeoPoint(latitude: 30.2651, longitude: -97.7426),
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        address: "621 Congress Ave, Austin, TX 78701",
        thumbnailUrl: nil,
        details: ["cuisine": "American", "priceRange": "$$$"]
      ),
      
      Place(
        id: "casino_el_camino",
        name: "Casino El Camino",
        primaryCategory: .drinks,
        tags: [.drinks, .music],
        rating: 4.7,
        reviewCount: 312,
        coordinates: GeoPoint(latitude: 30.2670, longitude: -97.7411),
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        address: "517 E 6th St, Austin, TX 78701",
        thumbnailUrl: nil,
        details: ["type": "dive bar", "priceRange": "$$"]
      ),
      Place(
        id: "firehouse_lounge",
        name: "Firehouse Lounge",
        primaryCategory: .drinks,
        tags: [.drinks, .music],
        rating: 4.7,
        reviewCount: 312,
        coordinates: GeoPoint(latitude: 30.2670, longitude: -97.7411),
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        address: "605 Brazos St, Austin, TX 78701",
        thumbnailUrl: nil,
        details: ["type": "Cocktail Bar", "priceRange": "$$"]
      ),
      
      Place(
        id: "floppy_disk_repair",
        name: "Floppy Disk Repair Co",
        primaryCategory: .drinks,
        tags: [.drinks],
        rating: 4.8,
        reviewCount: 156,
        coordinates: GeoPoint(latitude: 30.2665, longitude: -97.7362),
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        address: "119 E 5th St, Austin, TX 78701",
        thumbnailUrl: nil,
        details: ["type": "Speakeasy", "priceRange": "$$$"]
      ),
      
      Place(
        id: "zilker_botanical",
        name: "Zilker Botanical Garden",
        primaryCategory: .outdoors,
        tags: [.outdoors],
        rating: 4.6,
        reviewCount: 892,
        coordinates: GeoPoint(latitude: 30.2670, longitude: -97.7687),
        neighborhoodId: "ChIJQ8GHMSG1RIYRd7-_VfluNVg",
        address: "2220 Barton Springs Rd, Austin, TX 78746",
        thumbnailUrl: nil,
        details: ["type": "Garden", "admission": "$8-12"]
      ),
      
      Place(
        id: "zilker_park",
        name: "Zilker Metropolitan Park",
        primaryCategory: .outdoors,
        tags: [.outdoors],
        rating: 4.8,
        reviewCount: 1423,
        coordinates: GeoPoint(latitude: 30.2669, longitude: -97.7728),
        neighborhoodId: "ChIJQ8GHMSG1RIYRd7-_VfluNVg",
        address: "2207 Lou Neff Rd, Austin, TX 78746",
        thumbnailUrl: nil,
        details: ["type": "Park", "size": "351 acres"]
      )
    ]
    
    // Add all places
    for place in places {
      try await addPlace(place)
    }
    
    // Create content items matching videos to places
    let contentItems = [
      // Capitol District content
     
      Content(
        id: "caroline_highlight",
        placeIds: ["caroline_restaurant"],
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/caroline.mp4",
        thumbnailUrl: "",
        caption: "Weekend brunch vibes at Caroline 🍳",
        tags: [.restaurant, .drinks],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
       Content(
        id: "casino1",
        placeIds: ["casino_el_camino"],
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/casino.mp4",
        thumbnailUrl: "",
        caption: "Weekend brunch vibes at Caroline 🍳",
        tags: [.restaurant, .drinks],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
      
      Content(
        id: "firehouse_music",
        placeIds: ["firehouse_lounge"],
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/firehouse-music.mp4",
        thumbnailUrl: "",
        caption: "Live music at Firehouse 🎷",
        tags: [.drinks, .music],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
      Content(
        id: "casino2",
        placeIds: ["casino_el_camino"],
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/firehouse.mp4",
        thumbnailUrl: "",
        caption: "Anothe thing vibes �",
        tags: [.drinks],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
      
      Content(
        id: "floppy_drinks",
        placeIds: ["floppy_disk_repair"],
        neighborhoodId: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/floppy.mp4",
        thumbnailUrl: "",
        caption: "Secret speakeasy vibes 🍸",
        tags: [.drinks],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
      
      // Zilker content
      Content(
        id: "zilker_botanical",
        placeIds: ["zilker_botanical"],
        neighborhoodId: "ChIJQ8GHMSG1RIYRd7-_VfluNVg",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/zilker-botanical.mp4",
        thumbnailUrl: "",
        caption: "Spring blooms at Zilker Botanical Garden 🌸",
        tags: [.outdoors],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      ),
      
      Content(
        id: "zilker_park",
        placeIds: ["zilker_park"],
        neighborhoodId: "ChIJQ8GHMSG1RIYRd7-_VfluNVg",
        authorId: "test_author",
        videoUrl: "gs://sightline-app-gauntlet.firebasestorage.app/zilker.mp4",
        thumbnailUrl: "",
        caption: "Perfect day at Zilker Park ☀️",
        tags: [.outdoors],
        likes: Int.random(in: 50...200),
        views: Int.random(in: 500...2000)
      )
    ]
    
    // Add all content
    for content in contentItems {
      try await addContent(content)
    }
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
#endif
