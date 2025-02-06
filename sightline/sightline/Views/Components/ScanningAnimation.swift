import SwiftUI

struct ScanningAnimation: View {
    @State private var position: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            let halfHeight = geometry.size.height / 2
            // Adjusted scanning area positions relative to the centered coordinate space.
            let scanningTop = geometry.size.height * 0.1 - halfHeight
            let scanningBottom = geometry.size.height * 0.9 - halfHeight
            
            ZStack {
                // Scanner line
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear, 
                                .blue.opacity(0.5), 
                                .blue, 
                                .blue.opacity(0.5), 
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .offset(y: position)
                    .shadow(color: .blue.opacity(0.5), radius: 4)
                
                // Corner brackets defining the scanning area
                ScannerCorners()
                    .stroke(Color.white.opacity(0.7), lineWidth: 3)
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.8)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .onAppear {
                // Start animation from the adjusted top of the scanning area.
                position = scanningTop
                
                withAnimation(
                    .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                ) {
                    position = scanningBottom
                }
            }
        }
    }
}

struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength: CGFloat = 30
        
        // Top left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))
        
        // Top right corner
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))
        
        // Bottom right corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
        
        // Bottom left corner
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
        
        return path
    }
} 