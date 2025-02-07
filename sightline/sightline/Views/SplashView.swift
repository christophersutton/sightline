import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 1
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Border animation path
            BorderAnimation(progress: progress)
                .stroke(Color.blue, lineWidth: 10)
                .edgesIgnoringSafeArea(.all)
                .mask(
                    RoundedRectangle(cornerRadius: UIScreen.main.displayCornerRadius)
                        .edgesIgnoringSafeArea(.all)
                )
            
            VStack(spacing: 24) {
                // App Icon - using the correct asset name
//              let image = UIImage(named: "AppIcon")!
                Image("Icon-1024")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 10)
                
                VStack(spacing: 12) {
                    Text("SightLine")
                        .font(.custom("Baskerville", size: 24))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                progress = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onFinished()
                }
            }
        }
    }
}

extension UIScreen {
    var displayCornerRadius: CGFloat {
        let key = "_displayCornerRadius"
        if let val = self.value(forKey: key) as? CGFloat {
            return val
        }
        return 39
    }
}

struct BorderAnimation: Shape {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let cornerRadius = UIScreen.main.displayCornerRadius
        
        // Create the full rounded rectangle path
        let roundedRect = Path { path in
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            
            // Top edge and top-right corner
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            
            // Right edge and bottom-right corner
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            
            // Bottom edge and bottom-left corner
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
            
            // Left edge and top-left corner
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
        }
        
        // Trim the path based on progress
        return roundedRect.trimmedPath(from: 0, to: progress)
    }
}

#if DEBUG
struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView {
            print("Splash finished")
        }
        .previewDisplayName("Splash Screen")
    }
}
#endif 
