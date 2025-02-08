import SwiftUI

struct SplashView: View {
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 1
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // First border animation path (clockwise from top middle)
            BorderAnimation(progress: progress, startPosition: .topMiddle, clockwise: true)
                .stroke(Color.yellow, lineWidth: 10)
                .edgesIgnoringSafeArea(.all)
                .mask(
                    RoundedRectangle(cornerRadius: UIScreen.main.displayCornerRadius)
                        .edgesIgnoringSafeArea(.all)
                )
            
            // Second border animation path (counter-clockwise from top middle)
            BorderAnimation(progress: progress, startPosition: .topMiddle, clockwise: false)
                .stroke(Color.yellow, lineWidth: 10)
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

// Add enum for start position
enum BorderStartPosition {
    case topMiddle
}

struct BorderAnimation: Shape {
    var progress: CGFloat
    var startPosition: BorderStartPosition
    var clockwise: Bool
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let cornerRadius = UIScreen.main.displayCornerRadius
        
        return Path { path in
            // Start from top middle
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            
            if clockwise {
                // Top-right section
                path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false
                )
                
                // Right edge and remaining corners (clockwise)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false
                )
                
                path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
                path.addArc(
                    center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false
                )
                
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false
                )
                
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            } else {
                // Top-left section (counter-clockwise)
                path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
                path.addArc(
                    center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 180),
                    clockwise: true
                )
                
                // Left edge and remaining corners (counter-clockwise)
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 90),
                    clockwise: true
                )
                
                path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 0),
                    clockwise: true
                )
                
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))
                path.addArc(
                    center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: -90),
                    clockwise: true
                )
                
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            }
        }.trimmedPath(from: 0, to: progress)
    }
}

// Preview
struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView {
            print("Splash finished")
        }
        .previewDisplayName("Splash Screen")
    }
} 
