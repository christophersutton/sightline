import SwiftUI

struct NeighborhoodSelectorView: View {
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
        _viewModel = StateObject(wrappedValue: NeighborhoodSelectorViewModel(
            neighborhoodService: neighborhoodService,
            selectedNeighborhood: selectedNeighborhood
        ))
        _isExpanded = isExpanded
        self.onExploreMore = onExploreMore
        self.onNeighborhoodSelected = onNeighborhoodSelected
    }
    
    var body: some View {
        FloatingMenu(
            items: viewModel.neighborhoods,
            itemTitle: { $0.name },
            selectedId: viewModel.selectedNeighborhood?.id,
            onSelect: { neighborhood in
                viewModel.selectedNeighborhood = neighborhood
                isExpanded = false
                onNeighborhoodSelected()
            },
            alignment: .leading,
            isExpanded: $isExpanded,
            onExploreMore: onExploreMore
        )
        .task {
            await viewModel.loadNeighborhoods()
        }
    }
}

@MainActor
final class NeighborhoodSelectorViewModel: ObservableObject {
    @Published var neighborhoods: [Neighborhood] = []
    @Binding var selectedNeighborhood: Neighborhood?
    
    private let neighborhoodService: NeighborhoodService
    
    init(neighborhoodService: NeighborhoodService, selectedNeighborhood: Binding<Neighborhood?>) {
        self.neighborhoodService = neighborhoodService
        _selectedNeighborhood = selectedNeighborhood
    }
    
    func loadNeighborhoods() async {
        do {
            neighborhoods = try await neighborhoodService.fetchUnlockedNeighborhoods()
            if selectedNeighborhood == nil {
                selectedNeighborhood = neighborhoods.first
            }
        } catch {
            print("Error loading neighborhoods: \(error)")
        }
    }
} 