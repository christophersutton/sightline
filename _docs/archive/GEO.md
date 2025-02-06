Neighborhood-Based Content System Implementation

Implementation Goal:
Transition from Knowledge Graph API to Geocoding API for neighborhood-based content unlocking using Google's place_id as stable identifiers.
Key Changes Required:
1. Cloud Function (annotateImage):
Replace Knowledge Graph calls with Geocoding API reverse lookup
Return neighborhood data with place_id, bounds, and name
2. Firestore Structure:
Add neighborhoods collection with place metadata
Track user unlocks via unlocked_neighborhoods subcollection
Link content to neighborhoods via place_id arrays
3. iOS Modifications (LandmarkDetection.swift):
Update LandmarkInfo to store neighborhood place_id and bounds
Implement neighborhood unlocking on detection
Modify content queries to filter by unlocked place_ids
4. Fallback System:
Generate 6-character geohash zones when no neighborhood found
Treat geohash zones as temporary neighborhoods
Critical Requirements:
Use Google's place_id as primary neighborhood identifier
Maintain neighborhood metadata cache in Firestore
Handle content->neighborhood relationships at creation time
Support both precise neighborhoods and approximate geohash zones
First Files to Modify:
1. firebase/functions/index.js (Cloud Function)
2. sightline/LandmarkDetection.swift (iOS Model/View)



1. Core Architecture Data Flow

Landmark Detection → Geocoding API → Firestore → Content Unlocking

---

2. Backend Modifications

Cloud Function Additions

```js
// In annotateImage cloud function
async function getNeighborhoodFromCoords(lat, lng) {
const response = await mapsClient.reverseGeocode({
params: {
latlng: ${lat},${lng},
result_type: ['neighborhood'],
key: API_KEY
}
});
return response.data.results
.filter(r => r.types.includes('neighborhood'))
.map(r => ({
place_id: r.place_id,
name: r.address_components[0].long_name,
bounds: r.geometry.bounds
}));
}
```

---

3. Firestore Structure Neighborhoods Collection

```js
// /neighborhoods/{place_id}
{
name: "Capitol District",
place_id: "ChIJRyZGIaC1RIYRC6MZpgR-iT4",
bounds: {
ne: { lat: 30.2797, lng: -97.7354 },
sw: { lat: 30.2717, lng: -97.7445 }
},
geohash: "9v6yex1"
}
```

User Unlocks

```js
// /users/{uid}/unlocked_neighborhoods/{place_id}
{
first_unlocked: Timestamp,
last_accessed: Timestamp,
detection_count: number
}
```

---

4. iOS Implementation Updated Landmark Model

```swift
struct Neighborhood {
let placeID: String
let name: String
let bounds: GeoBounds
}
struct GeoBounds {
let northeast: CLLocationCoordinate2D
let southwest: CLLocationCoordinate2D
}
```

Unlocking Logic

```swift
func handleLandmarkDetection( landmark: LandmarkInfo) {
guard let location = landmark.location else { return }
Firestore.firestore().collection("users")
.document(uid)
.collection("unlocked_neighborhoods")
.document(neighborhood.placeID)
.setData([
"name": neighborhood.name,
"bounds": [
"ne": GeoPoint(latitude: neighborhood.bounds.ne.lat,
longitude: neighborhood.bounds.ne.lng),
"sw": GeoPoint(latitude: neighborhood.bounds.sw.lat,
longitude: neighborhood.bounds.sw.lng)
]
], merge: true)
}
```

---

5. Content Querying Fetch Unlocked Content

```js
func fetchContentForUser( userId: String) async throws -> [Content] {
let unlockedRefs = getUnlockedNeighborhoodIDs()
return try await Firestore.firestore().collection("content")
.whereField("neighborhoodIDs", arrayContainsAny: unlockedRefs)
.order(by: "timestamp", descending: true)
.limit(to: 50)
.getDocuments()
.documents
.compactMap { try $0.data(as: Content.self) }
}
```

---

6. Fallback System Geohash Handling

```js
// When no neighborhood found:
let geohash = Geohash.encode(lat: location.lat, lng: location.lng, precision: 6)
Firestore.firestore().collection("neighborhoods")
.document(geohash)
.setData([
"type": "geohash",
"center": GeoPoint(latitude: location.lat, longitude: location.lng),
"radius_m": 1000
])
```

---
