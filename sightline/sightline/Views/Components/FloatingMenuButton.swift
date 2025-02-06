import SwiftUI

// Helper modifier to conditionally apply modifiers.
extension View {
    @ViewBuilder func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

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

    // Namespace for matched geometry animations.
    @Namespace private var menuAnimation

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
        // Determine the trigger item – if none is selected, use the first.
        let triggerItem = items.first { $0.id == selectedId } ?? items.first

        VStack(alignment: alignment, spacing: 12) {
            // Trigger button at the top.
            VStack(alignment: alignment, spacing: 0) {
                FloatingMenuButton(
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)) {
//                            if items.count > 1 || onExploreMore == nil {
                                isExpanded.toggle()
//                            } else {
//                                onExploreMore?()
//                            }
                        }
                    },
                    isSelected: triggerItem?.id == selectedId,
                    expandHorizontally: alignment == .leading
                ) {
                    // When collapsed, apply the matched geometry effect so that a fly‑out item can animate into this spot.
                    // When expanded, show the text normally so it doesn’t disappear.
                    Text(triggerItem.map(itemTitle) ?? "")
                        .if(!isExpanded) { view in
                            view.matchedGeometryEffect(id: "menuItem", in: menuAnimation)
                        }
                }
            }

            // Fly-out list.
            VStack(alignment: alignment, spacing: 12) {
                ForEach(Array(items.filter { $0.id != triggerItem?.id }.enumerated()),
                        id: \.element.id) { index, item in
                    FloatingMenuButton(
                        action: {
                            withAnimation(
                                .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
                                    .delay(Double(index) * 0.05)
                            ) {
                                onSelect(item)
                                isExpanded = false
                            }
                        },
                        isSelected: item.id == selectedId,
                        expandHorizontally: alignment == .leading
                    ) {
                        // When expanded, if this is the selected item, attach the matched geometry effect.
                        Text(itemTitle(item))
                            .if(item.id == selectedId && isExpanded) { view in
                                view.matchedGeometryEffect(id: "menuItem", in: menuAnimation)
                            }
                    }
                    .offset(x: isExpanded ? 0 : (alignment == .leading ? -200 : 200))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
                            .delay(Double(index) * 0.05),
                        value: isExpanded
                    )
                }

                // "Explore More Areas" button.
//                if alignment == .leading && items.count <= 1 && onExploreMore != nil {
//                    FloatingMenuButton(
//                        action: {
//                            withAnimation(
//                                .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.0)
//                                    .delay(0.05)
//                            ) {
//                                onExploreMore?()
//                            }
//                        },
//                        expandHorizontally: true
//                    ) {
//                        Text("Explore More Areas")
//                    }
//                    .offset(x: isExpanded ? 0 : -200)
//                    .animation(
//                        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.0)
//                            .delay(0.05),
//                        value: isExpanded
//                    )
//                }
            }
            .clipped() // Hide off-screen content.
            .frame(height: isExpanded ? nil : 0) // Collapse height when not expanded.
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
            PreviewItem(id: "1", name: "Dashboard"),
            PreviewItem(id: "2", name: "Reports"),
            PreviewItem(id: "3", name: "Settings")
        ]

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 40) {
                    // Left-aligned menu.
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

                    // Right-aligned menu.
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

                    // Single item with explore more.
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
