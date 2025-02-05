import SwiftUI

struct FloatingMenuButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let isSelected: Bool
    
    init(
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Color.white
                    } else {
                        Color.white.opacity(0.2)
                    }
                }
                .background(.ultraThinMaterial)
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(20)
        }
    }
}

struct FloatingMenu<T: Identifiable>: View {
    let items: [T]
    let itemTitle: (T) -> String
    let selectedId: T.ID?
    let onSelect: (T) -> Void
    let alignment: HorizontalAlignment
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: alignment, spacing: 12) {
            // Show selected item as trigger, or first item if nothing selected
            let triggerItem = items.first { $0.id == selectedId } ?? items.first
            
            // Trigger button
            FloatingMenuButton(
                isSelected: triggerItem?.id == selectedId,
                action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
            ) {
                Text(triggerItem.map(itemTitle) ?? "")
            }
            
            // Rest of the items slide in when expanded
            if isExpanded {
                ForEach(Array(items.filter { $0.id != triggerItem?.id }.enumerated()), 
                       id: \.element.id) { index, item in
                    FloatingMenuButton(
                        isSelected: item.id == selectedId,
                        action: { 
                            print("Button tapped: \(itemTitle(item))")  // Add debug print
                            onSelect(item) 
                        }
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
            }
        }
        .padding(.horizontal)
    }
} 