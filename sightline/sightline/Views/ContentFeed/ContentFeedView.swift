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
        Group {
            if appStore.unlockedNeighborhoods.isEmpty {
                EmptyNeighborhoodState()
                    .onAppear { print("📱 No unlocked neighborhoods available") }
            } else if appStore.isLoadingContent {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .onAppear { print("📱 Loading content...") }
            } else if appStore.contentItems.isEmpty {
                Text("No content available")
                    .foregroundColor(.white)
                    .onAppear { print("📱 No content items available") }
            } else {
                feedView
            }
        }
    }

    private var feedView: some View {
        VerticalFeedView(
            currentIndex: $appStore.currentIndex,
            itemCount: appStore.contentItems.count,
            feedVersion: appStore.feedVersion,
            onIndexChanged: { newIndex, oldIndex in
                Task { @MainActor in
                    print("📱 Feed index changing from \(oldIndex) to \(newIndex)")
                    // 1) Pause the old video if it's valid
                    if oldIndex >= 0, oldIndex < appStore.contentItems.count {
                        let oldVideoUrl = appStore.contentItems[oldIndex].videoUrl
                        print("📱 Pausing video at URL: \(oldVideoUrl)")
                        appStore.videoManager.pause(url: oldVideoUrl)
                    }
                    
                    // 2) Update the store's currentIndex
                    appStore.currentIndex = newIndex
                    
                    // 3) Log the current content item
                    if newIndex >= 0 && newIndex < appStore.contentItems.count {
                        let content = appStore.contentItems[newIndex]
                        print("📱 Current content item: id=\(content.id), videoUrl=\(content.videoUrl)")
                    }
                }
            }
        ) { index in
            // Provide the ContentItemView
            if index >= 0 && index < appStore.contentItems.count {
                let content = appStore.contentItems[index]
                ContentItemView(content: content, appStore: appStore)
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
        .onAppear {
            print("📱 Feed view appeared with \(appStore.contentItems.count) items")
            // Ensure the first video starts playing when the feed appears
            if !appStore.contentItems.isEmpty {
                let firstVideo = appStore.contentItems[appStore.currentIndex]
                print("📱 Auto-playing first video: \(firstVideo.videoUrl)")
                appStore.videoManager.play(url: firstVideo.videoUrl)
            }
        }
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