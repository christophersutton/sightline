// sightline/sightline/Views/ContentFeedView/Components/NeighborhoodSelectorView.swift

import SwiftUI

struct NeighborhoodSelectorView: View {
    @Binding var selectedNeighborhood: Neighborhood?
    @EnvironmentObject var appStore: AppStore  // Use the AppStore here
    @Binding var isExpanded: Bool
    let onExploreMore: () -> Void
    let onNeighborhoodSelected: () -> Void

    var body: some View {
        FloatingMenu(
            items: appStore.unlockedNeighborhoods,  // Get neighborhoods from AppStore
            itemTitle: { $0.name },
            selectedId: selectedNeighborhood?.id,
            onSelect: { neighborhood in
                withAnimation {
                    appStore.contentItems = []
                    appStore.places = [:]
                    selectedNeighborhood = neighborhood
                    isExpanded = false
                    onNeighborhoodSelected()
                }
            },
            alignment: .leading,
            isExpanded: $isExpanded,
            onExploreMore: onExploreMore
        )
        .task {
            if appStore.unlockedNeighborhoods.isEmpty {  // Only load if needed
                await appStore.loadUnlockedNeighborhoods()
            }
            if selectedNeighborhood == nil, let first = appStore.unlockedNeighborhoods.first {
                selectedNeighborhood = first
                onNeighborhoodSelected()
            }
        }
    }
}
