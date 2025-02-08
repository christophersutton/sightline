import SwiftUI
import UIKit

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: ContentFeedViewModel  // <-- Replaced local @StateObject

    @State private var showingNeighborhoods = false
    @State private var showingCategories = false
    @State private var selectedPlaceId: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading {
                LoadingState()
            } else if !viewModel.hasLoadedNeighborhoods {
                LoadingState()
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
            
            // Menus
            HStack(alignment: .top) {
                // Neighborhood Selection
                NeighborhoodSelectorView(
                    neighborhoodService: ServiceContainer.shared.neighborhood,
                    selectedNeighborhood: $viewModel.selectedNeighborhood,
                    isExpanded: $showingNeighborhoods,
                    onExploreMore: {
                        appState.shouldSwitchToDiscover = true
                    },
                    onNeighborhoodSelected: {
                        Task {
                            await viewModel.loadContent()
                        }
                    }
                )
                
                Spacer()
                
                // Category Selection - now using .id(neighborhoodId) to force refresh
                if let neighborhoodId = viewModel.selectedNeighborhood?.id {
                    CategorySelectorView(
                        neighborhoodService: ServiceContainer.shared.neighborhood,
                        neighborhoodId: neighborhoodId,
                        selectedCategory: $viewModel.selectedCategory,
                        isExpanded: $showingCategories,
                        onCategorySelected: {
                            Task {
                                await viewModel.loadContent()
                            }
                        }
                    )
                    .id(neighborhoodId)   // <-- Forces reinitialization when neighborhoodId changes
                } else {
                    // Fallback in the unlikely case where no neighborhood is selected.
                    Text("Select a neighborhood")
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)
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
            if !viewModel.hasLoadedNeighborhoods {
                await viewModel.loadUnlockedNeighborhoods()
            }
            
            // If we have content but video isn't playing, start it
            if !viewModel.contentItems.isEmpty {
                viewModel.videoManager.currentPlayer?.play()
            }
        }
        // Add onAppear to handle tab switches
        .onAppear {
            // If we have a selectedNeighborhood but no content, load it
            if viewModel.selectedNeighborhood != nil && viewModel.contentItems.isEmpty {
                Task {
                    await viewModel.loadContent()
                }
            }
        }
    }
}

struct LoadingState: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading...")
                    .font(.custom("Baskerville", size: 18))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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