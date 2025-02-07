import SwiftUI

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentFeedViewModel()
    @State private var showingNeighborhoods = false
    @State private var showingCategories = false
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if viewModel.contentItems.isEmpty {
                    Text("No content available")
                        .foregroundColor(.white)
                } else {
                    VerticalFeedView(
                        currentIndex: $viewModel.currentIndex,
                        itemCount: viewModel.contentItems.count,
                        onIndexChanged: { index in
                            viewModel.currentIndex = index
                        }
                    ) { index in
                        if index < viewModel.contentItems.count {
                            ContentItemView(content: viewModel.contentItems[index])
                                .environmentObject(viewModel)
                        } else {
                            Color.black // Fallback view
                        }
                    }
                    .ignoresSafeArea()
                    .zIndex(0)
                }
                
                // Menus (without separate trigger buttons)
                HStack(alignment: .top) {
                    // Neighborhoods Menu
                    FloatingMenu(
                        items: viewModel.unlockedNeighborhoods,
                        itemTitle: { $0.name },
                        selectedId: viewModel.selectedNeighborhood?.id,
                        onSelect: { neighborhood in
                            viewModel.selectedNeighborhood = neighborhood
                            showingNeighborhoods = false
                            Task {
                                await viewModel.loadContent()
                            }
                        },
                        alignment: .leading,
                        isExpanded: $showingNeighborhoods,
                        onExploreMore: {
                            appState.shouldSwitchToDiscover = true
                        }
                    )
                    
                    Spacer()
                    
                    // Categories Menu
                    FloatingMenu(
                      items: viewModel.availableCategories,
                        itemTitle: { $0.rawValue.capitalized },
                        selectedId: viewModel.selectedCategory.rawValue,
                        onSelect: { category in
                            viewModel.categorySelected(category)
                            showingCategories = false
                        },
                        alignment: .trailing,
                        isExpanded: $showingCategories
                    )
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)  // Slightly increased padding for better edge spacing
                .zIndex(2)
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
