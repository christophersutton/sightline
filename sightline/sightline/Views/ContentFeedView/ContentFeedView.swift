import SwiftUI

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentFeedViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    neighborhoodSelector
                    categorySelector
                    
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.contentItems.isEmpty {
                        VStack {
                            Text("No content available")
                                .foregroundColor(.white)
                          
                        }
                    } else {
                        VerticalFeedView(
                            currentIndex: $viewModel.currentIndex,
                            itemCount: viewModel.contentItems.count,
                            onIndexChanged: { index in
                                viewModel.currentIndex = index
                            }
                        ) {
                            ForEach(viewModel.contentItems.indices, id: \.self) { index in
                                ContentItemView(content: viewModel.contentItems[index])
                                    .environmentObject(viewModel)
                            }
                        }
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
    }
    
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
