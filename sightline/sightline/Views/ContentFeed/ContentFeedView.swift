import SwiftUI
import UIKit

struct ContentFeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var appStore: AppStore

    @State private var showingNeighborhoods = false
    @State private var showingCategories = false
    @State private var selectedPlaceId: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            contentDisplay
                .zIndex(0)

            menuBar
                .zIndex(2)
        }
        .sheet(item: Binding(
            get: { selectedPlaceId.map { PlaceDetailPresentation(placeId: $0) } },
            set: { presentation in selectedPlaceId = presentation?.placeId }
        )) { presentation in
            PlaceDetailView(placeId: presentation.placeId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .task {
            await appStore.loadUnlockedNeighborhoods()
        }
    }

    // Subview for displaying the main content (loading, empty, or feed)
    @ViewBuilder
    private var contentDisplay: some View {
        if appStore.unlockedNeighborhoods.isEmpty {
            EmptyNeighborhoodState()
        } else if appStore.contentItems.isEmpty {
            Text("No content available").foregroundColor(.white)
        } else {
            feedView
        }
    }

  private var feedView: some View {
      VerticalFeedView(
          currentIndex: $appStore.currentIndex,
          itemCount: appStore.contentItems.count,
          onIndexChanged: { index in
              // Optionally, preload next items here.
          }
      ) { index in
          if index < appStore.contentItems.count {
              ContentItemView(content: appStore.contentItems[index])
                  .onTapGesture {
                      let placeIds = appStore.contentItems[index].placeIds
                      if !placeIds.isEmpty { selectedPlaceId = placeIds[0] }
                  }
          } else {
              Color.black
          }
      }
      .ignoresSafeArea()
  }
  
    // Subview for the top menu bar (neighborhood and category selectors)
    private var menuBar: some View {
        HStack(alignment: .top) {
            NeighborhoodSelectorView(
                selectedNeighborhood: $appStore.selectedNeighborhood,
                isExpanded: $showingNeighborhoods,
                onExploreMore: { appState.shouldSwitchToDiscover = true },
                onNeighborhoodSelected: { Task { await appStore.loadContent() } }
            )

            Spacer()

            if let neighborhoodId = appStore.selectedNeighborhood?.id {
                CategorySelectorView(
                    selectedCategory: $appStore.selectedCategory,
                    isExpanded: $showingCategories,
                    onCategorySelected: { Task { await appStore.loadContent() } }
                )
                .id(neighborhoodId)
            } else {
                Text("Select a neighborhood").foregroundColor(.white)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 16)
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



struct PlaceDetailPresentation: Identifiable {
    let id = UUID()
    let placeId: String
}
