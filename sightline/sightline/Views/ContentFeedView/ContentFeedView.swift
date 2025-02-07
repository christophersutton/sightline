import SwiftUI
import UIKit

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContentFeedViewModel()
    @State private var showingNeighborhoods = false
    @State private var showingCategories = false
    @State private var selectedPlaceId: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if viewModel.unlockedNeighborhoods.isEmpty {
                EmptyNeighborhoodState()
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
                            .onTapGesture {
                                let placeIds = viewModel.contentItems[index].placeIds
                                if !placeIds.isEmpty {
                                    selectedPlaceId = placeIds[0]
                                }
                            }
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
        .sheet(item: Binding(
            get: { 
                selectedPlaceId.map { PlaceDetailPresentation(placeId: $0) } 
            },
            set: { presentation in
                selectedPlaceId = presentation?.placeId
            }
        )) { presentation in
            PlaceDetailView(placeId: presentation.placeId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
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

struct EmptyNeighborhoodState: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack {
                    // Background Image
                    Image("nocontent")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    // Content Container
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            // Header
                            Text("Unlock Your First Neighborhood")
                                .font(.custom("Baskerville-Bold", size: 28))
                                .multilineTextAlignment(.center)
                            
                            Text("Discover local landmarks to unlock neighborhood content and start exploring stories from your community")
                                .font(.custom("Baskerville", size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                    }
                    .padding()
                }
                .frame(minHeight: geometry.size.height)
            }
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(edges: .top)
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

struct PlaceDetailPresentation: Identifiable {
    let id = UUID()
    let placeId: String
}


