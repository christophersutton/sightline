import SwiftUI

struct ScanningTransitionView: View {
    let namespace: Namespace.ID
    @State private var animateTransition = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dramatic blue scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .blue.opacity(0.9),
                                .blue,
                                .blue.opacity(0.9),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    // Increase the height a lot more then add a scale effect
                    .frame(height: animateTransition ? 100 : 3)
                    .shadow(color: .blue.opacity(animateTransition ? 1.0 : 0.5),
                            radius: animateTransition ? 30 : 4)
                    .matchedGeometryEffect(id: "scannerLine", in: namespace)
                    .opacity(animateTransition ? 0 : 1)
                
                // Drastically expand + rotate the scanner corners
                ScannerCorners()
                    .stroke(Color.white.opacity(0.7), lineWidth: animateTransition ? 1 : 3)
                    .frame(width: animateTransition ? geometry.size.width * 1.5 : geometry.size.width * 0.8,
                           height: animateTransition ? geometry.size.height * 1.5 : geometry.size.height * 0.8)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .matchedGeometryEffect(id: "scannerCorners", in: namespace)
                    .opacity(animateTransition ? 0 : 1)
            }
            .onAppear {
                // You can adjust the animation duration or add delays to chain effects.
                withAnimation(.easeInOut(duration: 1.2)) {
                    animateTransition = true
                }
            }
        }
        .ignoresSafeArea()
    }
} 
