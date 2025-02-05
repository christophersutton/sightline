import SwiftUI
import AVKit

struct PlaceDetailView: View {
    let place: Place
    let initialContentId: String?
    @StateObject private var viewModel = PlaceDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Content Area
                TabView(selection: $viewModel.currentIndex) {
                    ForEach(viewModel.contentItems.indices, id: \.self) { index in
                        ContentItemView(content: viewModel.contentItems[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
        }
        .task {
            await viewModel.loadContent(for: place.id, initialContentId: initialContentId)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(place.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            Text(place.address)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background {
            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

@MainActor
class PlaceDetailViewModel: ObservableObject {
    @Published var contentItems: [Content] = []
    @Published var currentIndex: Int = 0
    private let services = ServiceContainer.shared
    
    func loadContent(for placeId: String, initialContentId: String?) async {
        do {
            let content = try await services.firestore.fetchContentForPlace(placeId: placeId)
            
            // Sort content so that the initial content is first
            let sortedContent = content.sorted { first, second in
                if let initialId = initialContentId, first.id == initialId { return true }
                if let initialId = initialContentId, second.id == initialId { return false }
                return first.createdAt.seconds > second.createdAt.seconds
            }
            
            self.contentItems = sortedContent
            self.currentIndex = 0
        } catch {
            print("Error loading place content: \(error)")
        }
    }
}
