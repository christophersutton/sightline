import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class VideoReviewService {
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
            print("📝 Auth state:", currentUser.uid)
            
            let storagePath = "processing/\(placeId)/\(reviewId).mp4"
            print("📝 Storage path: \(storagePath)")
            
            // Create initial Firestore document with pending status
            let initialData: [String: Any] = [
                "id": reviewId,
                "placeIds": [placeId],
                "userId": currentUser.uid,
                "createdAt": FieldValue.serverTimestamp(),
                "processingStatus": "awaiting_upload",
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
            
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            print("📝 Using storage bucket:", storage.reference().bucket)
            
            print("📝 Uploading to Storage")
            _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            
            // Update document with video path to trigger processing
            try await firestore
                .collection("content")
                .document(reviewId)
                .updateData([
                    "videoPath": "gs://\(storage.reference().bucket)/\(storagePath)",
                    "videoUrl": downloadURL.absoluteString,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            print("✅ Upload complete for reviewId: \(reviewId)")
            return reviewId
            
        } catch {
            print("❌ Upload error: \(error)")
            if let storageError = error as? StorageErrorCode {
                print("Storage error code: \(storageError.rawValue)")
            }
            try? await firestore
                .collection("content")
                .document(reviewId)
                .updateData([
                    "processingStatus": "error",
                    "processingError": [
                        "stage": "upload",
                        "message": error.localizedDescription,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                ])
            throw error
        }
    }

    func listenToProcessingStatus(reviewId: String, completion: @escaping (String) -> Void) -> ListenerRegistration {
        let db = Firestore.firestore()
        return db.collection("content").document(reviewId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    completion("error")
                    return
                }
                
                guard let data = document.data(),
                      let status = data["processingStatus"] as? String else {
                    print("Document data was empty or missing processingStatus")
                    completion("error")
                    return
                }
                
                completion(status)
            }
    }
} 
