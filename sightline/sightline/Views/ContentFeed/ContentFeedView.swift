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
        // Display place detail in a sheet when tapped
        .sheet(item: Binding(
            get: { selectedPlaceId.map { PlaceDetailPresentation(placeId: $0) } },
            set: { presentation in selectedPlaceId = presentation?.placeId }
        )) {
            presentation in
            PlaceDetailView(placeId: presentation.placeId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        .task {
            // Load unlocked neighborhoods once
            await appStore.loadUnlockedNeighborhoods()
        }
    }

    @ViewBuilder
    private var contentDisplay: some View {
        if appStore.unlockedNeighborhoods.isEmpty {
            EmptyNeighborhoodState()
        } else if appStore.contentItems.isEmpty {
            Text("No content available")
                .foregroundColor(.white)
        } else {
            feedView
        }
    }

    private var feedView: some View {
        VerticalFeedView(
            currentIndex: $appStore.currentIndex,
            itemCount: appStore.contentItems.count,
            feedVersion: appStore.feedVersion,
            onIndexChanged: { index in
                if index >= 0 && index < appStore.contentItems.count {
                    appStore.currentIndex = index
                }
            }
        ) { index in
            if index >= 0 && index < appStore.contentItems.count {
                let content = appStore.contentItems[index]
                ContentItemView(content: content)
                    .environmentObject(appStore)
                    .onTapGesture {
                        if let placeId = content.placeIds.first {
                            selectedPlaceId = placeId
                        }
                    }
            } else {
                Color.black
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
    }

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

struct PlaceDetailPresentation: Identifiable {
    let id = UUID()
    let placeId: String
}