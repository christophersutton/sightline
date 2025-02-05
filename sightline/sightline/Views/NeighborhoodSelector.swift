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
                        selected = neighborhood
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}
