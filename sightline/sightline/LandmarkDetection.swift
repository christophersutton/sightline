import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import UIKit

class LandmarkDetectionViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var detectionResult: String = ""
    let imageNames = ["utcapitol1", "utcapitol2", "ladybirdlake1"]
    private lazy var functions = Functions.functions()
    
    func detectLandmark(for image: UIImage) {
        detectionResult = "Detecting..."
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            detectionResult = "Image conversion failed."
            return
        }
        let base64String = imageData.base64EncodedString()
        
        let requestData: [String: Any] = [
            "image": ["content": base64String],
            "features": [
                ["maxResults": 5, "type": "LANDMARK_DETECTION"]
            ]
        ]
        
        Task {
            do {
                let result = try await functions.httpsCallable("annotateImage").call(requestData)
                if let dict = result.data as? [String: Any],
                   let annotations = dict["landmarkAnnotations"] as? [[String: Any]],
                   let firstLandmark = annotations.first,
                   let landmarkName = firstLandmark["description"] as? String {
                    
                    await MainActor.run {
                        detectionResult = landmarkName
                    }
                    saveDetectionResult(landmarkName: landmarkName)
                } else {
                    await MainActor.run {
                        detectionResult = "No landmarks detected."
                    }
                    saveDetectionResult(landmarkName: "None")
                }
            } catch {
                await MainActor.run {
                    detectionResult = "Error: \(error.localizedDescription)"
                }
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveDetectionResult(landmarkName: String) {
        let db = Firestore.firestore()
        let landmarkData: [String: Any] = [
            "name": landmarkName,
            "detectedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("detectedLandmarks").addDocument(data: landmarkData) { error in
            if let error = error {
                print("Error saving detection result: \(error.localizedDescription)")
            }
        }
    }
}
struct LandmarkDetectionView: View {
    @StateObject private var viewModel = LandmarkDetectionViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .padding()
                } else {
                    Text("Select an image to detect a landmark")
                        .padding()
                }
                
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(viewModel.imageNames, id: \.self) { name in
                            Image(name)
                                .resizable()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                                .padding(4)
                                .onTapGesture {
                                    if let uiImage = UIImage(named: name) {
                                        viewModel.selectedImage = uiImage
                                        viewModel.detectLandmark(for: uiImage)
                                    }
                                }
                        }
                    }
                }
                
                if !viewModel.detectionResult.isEmpty {
                    Text("Detection Result: \(viewModel.detectionResult)")
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Landmark Detection")
        }
    }
}

struct LandmarkDetectionView_Previews: PreviewProvider {
    static var previews: some View {
        LandmarkDetectionView()
    }
}
