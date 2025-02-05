import SwiftUI
import AVKit

struct PlaceDetailView: View {
    let placeId: String
    let initialContentId: String
    @StateObject private var viewModel: PlaceDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(placeId: String, initialContentId: String) {
        self.placeId = placeId
        self.initialContentId = initialContentId
        _viewModel = StateObject(wrappedValue: PlaceDetailViewModel())
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Content carousel
                TabView {
                    ForEach(viewModel.contentItems) { content in
                        ContentItemView(content: content)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .task {
            await viewModel.loadPlaceDetails(placeId: placeId)
            await viewModel.loadPlaceContent(placeId: placeId, initialContentId: initialContentId)
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if let place = viewModel.place {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Placeholder to balance the back button
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding()
            
            if let place = viewModel.place {
                Text(place.address)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .background(.ultraThinMaterial)
    }
}

@MainActor
class PlaceDetailViewModel: ObservableObject {
    @Published private(set) var place: Place?
    @Published private(set) var contentItems: [Content] = []
    private let services = ServiceContainer.shared
    
    func loadPlaceDetails(placeId: String) async {
        do {
            let place = try await services.firestore.fetchPlace(id: placeId)
            await MainActor.run {
                self.place = place
            }
        } catch {
            print("Error loading place details: \(error)")
        }
    }
    
    func loadPlaceContent(placeId: String, initialContentId: String) async {
        do {
            let content = try await services.firestore.fetchContentForPlace(placeId: placeId)
            
            await MainActor.run {
                // Sort content so that initialContentId appears first
                self.contentItems = content.sorted { first, second in
                    if first.id == initialContentId { return true }
                    if second.id == initialContentId { return false }
                    return first.createdAt.dateValue() > second.createdAt.dateValue()
                }
            }
        } catch {
            print("Error loading place content: \(error)")
        }
    }
}

