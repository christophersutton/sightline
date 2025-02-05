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
                // Main background layers
                .background {
                    if isSelected {
                        Color.white.opacity(0.2)
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
                .background(.ultraThinMaterial)
                .foregroundColor(.white)
                .cornerRadius(25)
                // Multiple shadows for depth
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)  // Outer shadow
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)   // Close shadow for depth
                // Layered overlays for texture
                .overlay {
                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [
                            .white.opacity(0.4),
                            .white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(25)
                    .opacity(0.5)
                }
                .overlay {
                    // Inner ring
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .overlay {
                    // Top edge highlight
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            .white.opacity(0.5),
                            lineWidth: 1
                        )
                        .mask {
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        }
                }
        }
        // Button press effect
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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