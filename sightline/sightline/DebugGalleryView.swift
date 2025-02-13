//import SwiftUI
//
//struct DebugGalleryView: View {
//    let imageNames: [String]
//    private let detectionService = LandmarkDetectionService()
//    @StateObject private var viewModel = LandmarkDetectionViewModel()
//    @Environment(\.dismiss) private var dismiss
//    
//    init(imageNames: [String]) {
//        self.imageNames = imageNames
//    }
//    
//    private let columns = [
//        GridItem(.flexible()),
//        GridItem(.flexible()),
//        GridItem(.flexible())
//    ]
//    
//    var body: some View {
//        NavigationView {
//            ScrollView {
//                LazyVGrid(columns: columns, spacing: 16) {
//                    ForEach(imageNames, id: \.self) { imageName in
//                        if let uiImage = UIImage(named: imageName) {
//                            Button {
//                                Task {
//                                    await viewModel.detectLandmark(image: uiImage, using: detectionService)
//                                    if viewModel.detectedLandmark != nil {
//                                        dismiss()
//                                    }
//                                }
//                            } label: {
//                                Image(uiImage: uiImage)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 100, height: 100)
//                                    .clipped()
//                                    .cornerRadius(8)
//                            }
//                            .overlay {
//                                if !viewModel.errorMessage.isEmpty {
//                                    Color.black.opacity(0.3)
//                                    Text(viewModel.errorMessage)
//                                        .font(.caption)
//                                        .foregroundColor(.white)
//                                        .padding(4)
//                                }
//                            }
//                        } else {
//                            RoundedRectangle(cornerRadius: 8)
//                                .fill(Color.gray)
//                                .frame(width: 100, height: 100)
//                                .overlay(Text("No Image")
//                                    .foregroundColor(.white)
//                                    .font(.caption)
//                                )
//                        }
//                    }
//                }
//                .padding()
//            }
//            .navigationTitle("Debug Gallery")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    DebugGalleryView(imageNames: ["utcapitol1", "utcapitol2", "ladybirdlake1"])
//} 
