// sightline/sightline/Views/ContentFeedView/Components/CategorySelectorView.swift
import SwiftUI
@MainActor
struct CategorySelectorView: View {
  @Binding var selectedCategory: FilterCategory
  @EnvironmentObject var appStore: AppStore // Use the AppStore for categories
    @Binding var isExpanded: Bool
    let onCategorySelected: () -> Void
    
    var body: some View {
        FloatingMenu(
          items: appStore.availableCategories,
          itemTitle: {$0.rawValue.capitalized},
          selectedId: selectedCategory.rawValue,
          onSelect: {category in
            appStore.contentItems = []
            appStore.places = [:]
            selectedCategory = category
            isExpanded = false
            onCategorySelected()
          },
          alignment: .trailing,
          isExpanded: $isExpanded
        ).task {
          await appStore.loadAvailableCategories() // Moved to AppStore
        }
    }
}
