import SwiftUI

struct DebugGalleryView: View {
    let imageNames: [String]
    @StateObject private var viewModel: LandmarkDetectionViewModel
    
    init(imageNames: [String], appState: AppState) {
        self.imageNames = imageNames
        self._viewModel = StateObject(wrappedValue: LandmarkDetectionViewModel(appState: appState))
    }
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(imageNames, id: \.self) { imageName in
                        if let uiImage = UIImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    viewModel.isLoading ?
                                    ProgressView()
                                        .background(Color.black.opacity(0.3))
                                    : nil
                                )
                                .onTapGesture {
                                    Task {
                                        await viewModel.detectLandmark(for: uiImage)
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray)
                                .frame(width: 100, height: 100)
                                .overlay(Text("No Image")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Landmark Detection")
            .navigationBarTitleDisplayMode(.inline)
            
            if let landmark = viewModel.detectedLandmark {
                LandmarkDetailView(landmark: landmark)
            }
        }
    }
}

struct DebugGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        DebugGalleryView(
            imageNames: ["utcapitol1", "utcapitol2", "ladybirdlake1"],
            appState: AppState()
        )
    }
} 