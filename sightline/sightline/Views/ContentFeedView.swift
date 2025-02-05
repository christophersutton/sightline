import SwiftUI
import FirebaseFirestore

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentFeedViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    neighborhoodSelector
                    categorySelector
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.contentItems.isEmpty {
                        Spacer()
                        VStack {
                            Text("No content available")
                                .foregroundColor(.white)
                            
                            #if DEBUG
                            Button(action: {
                                Task {
                                    try? await viewModel.loadTestData()
                                }
                            }) {
                                Text("Load Test Data")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            #endif
                        }
                        Spacer()
                    } else {
                        contentFeed
                    }
                }
            }
            .navigationDestination(for: AppState.NavigationDestination.self) { destination in
                switch destination {
                case .placeDetail(let placeId, let initialContentId):
                    PlaceDetailView(placeId: placeId, initialContentId: initialContentId)
                }
            }
        }
        .task {
            await viewModel.loadUnlockedNeighborhoods()
            await viewModel.loadContent()
        }
        .onChange(of: appState.lastUnlockedNeighborhoodId) { oldValue, newValue in
            if let newId = newValue,
               let neighborhood = viewModel.unlockedNeighborhoods.first(where: { $0.id == newId }) {
                viewModel.selectedNeighborhood = neighborhood
                Task {
                    await viewModel.loadContent()
                }
            }
        }
    }
    
    // Break up into smaller views
    private var neighborhoodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.unlockedNeighborhoods) { neighborhood in
                    NeighborhoodPill(
                        neighborhood: neighborhood,
                        isSelected: viewModel.selectedNeighborhood?.id == neighborhood.id
                    )
                    .onTapGesture {
                        viewModel.selectedNeighborhood = neighborhood
                        Task {
                            await viewModel.loadContent()
                        }
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
    
    private var categorySelector: some View {
        HStack(spacing: 16) {
            CategoryPill(title: "Restaurants", isSelected: viewModel.selectedCategory == .restaurant)
                .onTapGesture { viewModel.categorySelected(.restaurant) }
            CategoryPill(title: "Events", isSelected: viewModel.selectedCategory == .event)
                .onTapGesture { viewModel.categorySelected(.event) }
        }
        .padding(.vertical, 12)
    }
    
    private var contentFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.contentItems.indices, id: \.self) { index in
                        ContentItemView(content: viewModel.contentItems[index])
                            .frame(height: UIScreen.main.bounds.height)
                            .id(index)
                            .onAppear {
                                viewModel.currentIndex = index
                            }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollTargetLayout()
        }
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.white.opacity(0.2))
            .foregroundColor(isSelected ? .black : .white)
            .cornerRadius(20)
    }
} 