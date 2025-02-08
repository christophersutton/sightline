import SwiftUI

struct NeighborhoodSelectorView: View {
    @Binding var selectedNeighborhood: Neighborhood?
    @StateObject private var viewModel: NeighborhoodSelectorViewModel
    @Binding var isExpanded: Bool
    let onExploreMore: () -> Void
    let onNeighborhoodSelected: () -> Void
    
    init(
        neighborhoodService: NeighborhoodService,
        selectedNeighborhood: Binding<Neighborhood?>,
        isExpanded: Binding<Bool>,
        onExploreMore: @escaping () -> Void,
        onNeighborhoodSelected: @escaping () -> Void
    ) {
        _selectedNeighborhood = selectedNeighborhood
        _viewModel = StateObject(wrappedValue: NeighborhoodSelectorViewModel(neighborhoodService: neighborhoodService))
        _isExpanded = isExpanded
        self.onExploreMore = onExploreMore
        self.onNeighborhoodSelected = onNeighborhoodSelected
    }
    
    var body: some View {
        FloatingMenu(
            items: viewModel.neighborhoods,
            itemTitle: { $0.name },
            selectedId: selectedNeighborhood?.id,
            onSelect: { neighborhood in
                selectedNeighborhood = neighborhood
                isExpanded = false
                onNeighborhoodSelected()
            },
            alignment: .leading,
            isExpanded: $isExpanded,
            onExploreMore: onExploreMore
        )
        .task {
            await viewModel.loadNeighborhoods()
            if selectedNeighborhood == nil, let first = viewModel.neighborhoods.first {
                selectedNeighborhood = first
            }
        }
    }
}

@MainActor
final class NeighborhoodSelectorViewModel: ObservableObject {
    @Published var neighborhoods: [Neighborhood] = []
    
    private let neighborhoodService: NeighborhoodService
    
    init(neighborhoodService: NeighborhoodService) {
        self.neighborhoodService = neighborhoodService
    }
    
    func loadNeighborhoods() async {
        do {
            neighborhoods = try await neighborhoodService.fetchUnlockedNeighborhoods()
        } catch {
            print("Error loading neighborhoods: \(error)")
        }
    }
} 