import SwiftUI

struct FloatingMenuButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let isSelected: Bool
    let expandHorizontally: Bool
    
    @State private var buttonFrame: CGRect = .zero
    
    init(
        action: @escaping () -> Void,
        isSelected: Bool = false,
        expandHorizontally: Bool = false,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isSelected = isSelected
        self.expandHorizontally = expandHorizontally
        self.label = label
    }
    
    var body: some View {
        AdaptiveColorButton(
            isSelected: isSelected,
            expandHorizontally: expandHorizontally,
            action: action,
            label: label
        )
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    buttonFrame = geo.frame(in: .global)
                }
            }
        )
    }
}

struct FloatingMenu<T: Identifiable>: View {
    let items: [T]
    let itemTitle: (T) -> String
    let selectedId: T.ID?
    let onSelect: (T) -> Void
    let alignment: HorizontalAlignment
    @Binding var isExpanded: Bool
    let onExploreMore: (() -> Void)?  // Optional parameter
    
    init(
        items: [T],
        itemTitle: @escaping (T) -> String,
        selectedId: T.ID?,
        onSelect: @escaping (T) -> Void,
        alignment: HorizontalAlignment,
        isExpanded: Binding<Bool>,
        onExploreMore: (() -> Void)? = nil  // Default value of nil
    ) {
        self.items = items
        self.itemTitle = itemTitle
        self.selectedId = selectedId
        self.onSelect = onSelect
        self.alignment = alignment
        self._isExpanded = isExpanded
        self.onExploreMore = onExploreMore
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 12) {
            // Determine the trigger (selected) item
            let triggerItem = items.first { $0.id == selectedId } ?? items.first
            
            // Fix trigger button initialization
            FloatingMenuButton(
                action: {
                    withAnimation {
                        if items.count > 1 || onExploreMore == nil {
                            isExpanded.toggle()
                        } else {
                            onExploreMore?()
                        }
                    }
                },
                isSelected: triggerItem?.id == selectedId,
                expandHorizontally: alignment == .leading
            ) {
                Text(triggerItem.map(itemTitle) ?? "")
            }
            
            // Additional items slide in when expanded
            if isExpanded {
                ForEach(Array(items.filter { $0.id != triggerItem?.id }.enumerated()),
                        id: \.element.id) { index, item in
                    FloatingMenuButton(
                        action: { onSelect(item) },
                        isSelected: item.id == selectedId,
                        expandHorizontally: alignment == .leading
                    ) {
                        Text(itemTitle(item))
                    }
                    .offset(x: isExpanded ? 0 : alignment == .leading ? -100 : 100)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(
                        .spring(
                            response: 0.3,
                            dampingFraction: 0.8,
                            blendDuration: 0
                        )
                        .delay(Double(index) * 0.1),
                        value: isExpanded
                    )
                }
                
                // "Explore More Areas" button for neighborhoods with a single item
                if alignment == .leading && items.count <= 1 && onExploreMore != nil {
                    FloatingMenuButton(
                        action: { onExploreMore?() },
                        expandHorizontally: true
                    ) {
                        Text("Explore More Areas")
                    }
                    .offset(x: isExpanded ? 0 : -100)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(
                        .spring(
                            response: 0.3,
                            dampingFraction: 0.8,
                            blendDuration: 0
                        )
                        .delay(0.1),
                        value: isExpanded
                    )
                }
            }
        }
        // Removed the extra horizontal padding here so that the parent provides the outer margins.
    }
} 
