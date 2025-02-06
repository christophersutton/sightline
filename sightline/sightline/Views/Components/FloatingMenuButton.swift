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
        let triggerItem = items.first { $0.id == selectedId } ?? items.first
        
        VStack(alignment: alignment, spacing: 12) {
            // Trigger button
            VStack(alignment: alignment, spacing: 0) {
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
            }
            
            // Replace if with always-present content that's moved off-screen
            VStack(alignment: alignment, spacing: 12) {
                ForEach(Array(items.filter { $0.id != triggerItem?.id }.enumerated()),
                        id: \.element.id) { index, item in
                    FloatingMenuButton(
                        action: { onSelect(item) },
                        isSelected: item.id == selectedId,
                        expandHorizontally: alignment == .leading
                    ) {
                        Text(itemTitle(item))
                    }
                    .offset(x: isExpanded ? 0 : (alignment == .leading ? -200 : 200))
                    .animation(
                        .spring(
                            response: 0.4,
                            dampingFraction: 0.8,
                            blendDuration: 0.1
                        )
                        .delay(Double(index) * 0.05),
                        value: isExpanded
                    )
                }
                
                // "Explore More Areas" button
                if alignment == .leading && items.count <= 1 && onExploreMore != nil {
                    FloatingMenuButton(
                        action: { onExploreMore?() },
                        expandHorizontally: true
                    ) {
                        Text("Explore More Areas")
                    }
                    .offset(x: isExpanded ? 0 : -200)
                    .animation(
                        .spring(
                            response: 0.4,
                            dampingFraction: 0.8,
                            blendDuration: 0
                        )
                        .delay(0.05),
                        value: isExpanded
                    )
                }
            }
            .clipped() // Ensure off-screen content is hidden
            .frame(height: isExpanded ? nil : 0) // Collapse height when not expanded
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview("FloatingMenu") {
    struct PreviewItem: Identifiable {
        let id: String
        let name: String
    }
    
    struct PreviewWrapper: View {
        @State private var leftExpanded = false
        @State private var rightExpanded = false
        @State private var singleExpanded = false
        @State private var leftSelected = "1"
        @State private var rightSelected = "2"
        
        let items = [
            PreviewItem(id: "1", name: "Zilker"),
            PreviewItem(id: "2", name: "Capitol District"),
            PreviewItem(id: "3", name: "Downtown")
        ]
        
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Left-aligned menu
                    FloatingMenu(
                        items: items,
                        itemTitle: { $0.name },
                        selectedId: leftSelected,
                        onSelect: { item in
                            leftSelected = item.id
                            leftExpanded = false
                        },
                        alignment: .leading,
                        isExpanded: $leftExpanded
                    )
                    
                    // Right-aligned menu
                    FloatingMenu(
                        items: items,
                        itemTitle: { $0.name },
                        selectedId: rightSelected,
                        onSelect: { item in
                            rightSelected = item.id
                            rightExpanded = false
                        },
                        alignment: .trailing,
                        isExpanded: $rightExpanded
                    )
                    
                    // Single item with explore more
                    FloatingMenu(
                        items: [items[0]],
                        itemTitle: { $0.name },
                        selectedId: "1",
                        onSelect: { _ in },
                        alignment: .leading,
                        isExpanded: $singleExpanded,
                        onExploreMore: {}
                    )
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
} 
