import SwiftUI
import FirebaseFirestore

struct ContentFeedView: View {
    @StateObject private var viewModel = ContentFeedViewModel()
    @State private var selectedCategory: String = "restaurant"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Base background
            
            VStack(spacing: 0) {
                // Neighborhood Selector
                NeighborhoodSelector(
                    neighborhoods: viewModel.unlockedNeighborhoods,
                    selected: $viewModel.selectedNeighborhood
                )
                .padding(.top, 60) // Account for status bar
                
                // Category Pills
                HStack(spacing: 16) {
                    CategoryPill(title: "Restaurants", isSelected: selectedCategory == "restaurant")
                        .onTapGesture { selectedCategory = "restaurant" }
                    CategoryPill(title: "Events", isSelected: selectedCategory == "event")
                        .onTapGesture { selectedCategory = "event" }
                }
                .padding(.vertical, 12)
                
                // Content Feed
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
            await viewModel.loadUnlockedNeighborhoods()
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