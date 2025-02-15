import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class VideoReviewService {
    // Use default Storage configuration
    private let storage = Storage.storage()
    private let functions = Functions.functions()
    private let firestore = Firestore.firestore()
    
    func uploadReview(videoURL: URL, placeId: String) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "VideoReviewService", 
                         code: 401, 
                         userInfo: [NSLocalizedDescriptionKey: "User must be logged in to upload reviews"])
        }
        
        let reviewId = UUID().uuidString
        
        do {
            print("📝 Starting upload for reviewId: \(reviewId)")
            print("📝 Auth state: uid=\(currentUser.uid), token=\(currentUser.refreshToken ?? "none")")
            
            // Print Firebase app configuration
            print("📝 Firebase configuration:")
            let app = storage.app  // app is non-optional
            print("  - App name:", app.name)
            print("  - Options:", app.options.projectID ?? "no project id")
            print("  - Storage bucket:", app.options.storageBucket ?? "no bucket")
            
            let storagePath = "processing/\(placeId)/\(reviewId).mp4"
            print("📝 Storage path: \(storagePath)")
            
            // Add size check
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            print("📝 File size: \(fileSize) bytes")
            
            // Create initial Firestore document with pending status
            let initialData: [String: Any] = [
                "id": reviewId,
                "placeIds": [placeId],
                "userId": currentUser.uid,
                "createdAt": FieldValue.serverTimestamp(),
                "processingStatus": ProcessingState.created.rawValue,
                "neighborhoodId": "",
                "caption": "",
                "thumbnailUrl": "",
                "tags": [],
                "likes": 0,
                "views": 0,
                "transcription": "",
                "moderationResults": [:],
                "processingError": [:],
                "startedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            print("📝 Creating Firestore document")
            try await firestore
                .collection("content")
                .document(reviewId)
                .setData(initialData)
            
            print("📝 Reading video data")
            let videoData = try Data(contentsOf: videoURL)
            let storageRef = storage.reference().child(storagePath)
            
            // More explicit metadata
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            metadata.customMetadata = [
                "userId": currentUser.uid,
                "placeId": placeId,
                "uploadTimestamp": "\(Date().timeIntervalSince1970)"
            ]
            
            print("📝 Using storage bucket:", storage.reference().bucket)
            print("📝 Metadata:", metadata.dictionaryRepresentation())
            
            print("📝 Uploading to Storage")
            let result = try await storageRef.putDataAsync(videoData, metadata: metadata)
            print("📝 Upload metadata result:", result.dictionaryRepresentation())
            
            // Update document with video path to trigger processing
            try await firestore
                .collection("content")
                .document(reviewId)
                .updateData([
                    "videoUrl": "gs://\(storage.reference().bucket)/\(storagePath)",
                    "processingStatus": ProcessingState.readyForTranscription.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            print("✅ Upload complete for reviewId: \(reviewId)")
            return reviewId
            
        } catch {
            print("❌ Upload error: \(error)")
            if let storageError = error as? StorageErrorCode {
                print("Storage error code: \(storageError.rawValue)")
                print("Storage error description: \(storageError.localizedDescription)")
            }
            
            // Add more detailed error logging
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error user info: \(nsError.userInfo)")
            }
            
            try? await firestore
                .collection("content")
                .document(reviewId)
                .updateData([
                    "processingStatus": ProcessingState.failed.rawValue,
                    "processingError": [
                        "stage": "upload",
                        "message": error.localizedDescription,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                ])
            throw error
        }
    }

    func listenToProcessingStatus(reviewId: String, completion: @escaping (ProcessingState) -> Void) -> ListenerRegistration {
        let db = Firestore.firestore()
        return db.collection("content").document(reviewId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    completion(.failed)
                    return
                }
                
                guard let data = document.data(),
                      let statusString = data["processingStatus"] as? String,
                      let status = ProcessingState(rawValue: statusString) else {
                    print("Document data was empty or had invalid processingStatus")
                    completion(.failed)
                    return
                }
                
                completion(status)
            }
    }
} 
