import SwiftUI
import FirebaseFirestore

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentFeedViewModel()
    @State private var showingNeighborhoods = false
    @State private var showingCategories = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            contentFeed
                .zIndex(0)
            
            // Just the menus, no separate trigger buttons
            HStack {
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
                    isExpanded: $showingNeighborhoods
                )
                
                Spacer()
                
                // Categories Menu
                FloatingMenu(
                    items: ContentType.allCases,
                    itemTitle: { $0.rawValue.capitalized },
                    selectedId: viewModel.selectedCategory.rawValue,
                    onSelect: { category in
                        print("Selected category: \(category.rawValue)")
                        viewModel.categorySelected(category)
                        showingCategories = false
                    },
                    alignment: .trailing,
                    isExpanded: $showingCategories
                )
            }
            .padding(.top, 44) // Increase top padding to account for status bar
            .padding(.horizontal)
            .zIndex(2)
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
    
    private var contentFeed: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height)
                    } else {
                        ForEach(viewModel.contentItems.indices, id: \.self) { index in
                            ContentItemView(content: viewModel.contentItems[index])
                                .frame(
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height,
                                    alignment: .center
                                )
                                .id(index)
                                .onAppear {
                                    viewModel.currentIndex = index
                                }
                        }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollTargetLayout()
            .ignoresSafeArea()  // Make scroll view edge-to-edge
            .onChange(of: viewModel.contentItems) { oldValue, newValue in
                withAnimation {
                    proxy.scrollTo(0, anchor: .top)
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