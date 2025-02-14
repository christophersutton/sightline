import SwiftUI

struct AdaptiveColorButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let isSelected: Bool
    let expandHorizontally: Bool

    init(
        isSelected: Bool = false,
        expandHorizontally: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.expandHorizontally = expandHorizontally
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            label()
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: 36)
                .background(.thinMaterial)
                .cornerRadius(8)
                .fixedSize(horizontal: !expandHorizontally, vertical: false)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AdaptiveColorButton {
            print("Tapped")
        } label: {
            Text("Default Button")
        }
        
        AdaptiveColorButton(expandHorizontally: true) {
            print("Tapped")
        } label: {
            Text("Expanded Button")
        }
        
        AdaptiveColorButton {
            print("Tapped")
        } label: {
            HStack {
                Image(systemName: "star.fill")
                Text("Icon Button")
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.black)
}