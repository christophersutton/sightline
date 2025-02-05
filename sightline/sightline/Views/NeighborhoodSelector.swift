import SwiftUI

struct NeighborhoodSelector: View {
    let neighborhoods: [Neighborhood]
    @Binding var selected: Neighborhood?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(neighborhoods) { neighborhood in
                    NeighborhoodPill(
                        neighborhood: neighborhood,
                        isSelected: selected?.id == neighborhood.id
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selected = neighborhood
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .blur(radius: 3)
                .ignoresSafeArea()
        }
    }
}

struct NeighborhoodPill: View {
    let neighborhood: Neighborhood
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text("📍") // We can customize icons per neighborhood later
            Text(neighborhood.name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(isSelected ? .white : .white.opacity(0.3))
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }
        }
        .foregroundColor(isSelected ? .black : .white)
    }
} 