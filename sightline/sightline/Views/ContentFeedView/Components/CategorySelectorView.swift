import SwiftUI

@MainActor
final class CategorySelectorViewModel: ObservableObject {
    @Published var categories: [FilterCategory] = []
    
    private let neighborhoodService: NeighborhoodService
    let neighborhoodId: String

    init(neighborhoodId: String, neighborhoodService: NeighborhoodService) {
        self.neighborhoodId = neighborhoodId
        self.neighborhoodService = neighborhoodService
    }
    
    func loadCategories() async {
        do {
            let fetched = try await neighborhoodService.fetchAvailableCategories(neighborhoodId: neighborhoodId)
            categories = fetched
        } catch {
            print("Error loading categories: \(error)")
            // You might later want to add proper error state handling here.
        }
    }
}

struct CategorySelectorView: View {
    @Binding var selectedCategory: FilterCategory
    @StateObject private var viewModel: CategorySelectorViewModel
    @Binding var isExpanded: Bool
    let onCategorySelected: () -> Void
    
    init(
        neighborhoodService: NeighborhoodService,
        neighborhoodId: String,
        selectedCategory: Binding<FilterCategory>,
        isExpanded: Binding<Bool>,
        onCategorySelected: @escaping () -> Void
    ) {
        _selectedCategory = selectedCategory
        _viewModel = StateObject(wrappedValue: CategorySelectorViewModel(
            neighborhoodId: neighborhoodId,
            neighborhoodService: neighborhoodService
        ))
        _isExpanded = isExpanded
        self.onCategorySelected = onCategorySelected
    }
    
    var body: some View {
        FloatingMenu(
            items: viewModel.categories,
            itemTitle: { $0.rawValue.capitalized },
            selectedId: selectedCategory.rawValue,
            onSelect: { category in
                selectedCategory = category
                isExpanded = false
                onCategorySelected()
            },
            alignment: .trailing,
            isExpanded: $isExpanded
        )
        .task {
            await viewModel.loadCategories()
        }
    }
} 