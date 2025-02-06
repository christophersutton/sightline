import SwiftUI
import UIKit

struct AdaptiveColorButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    let isSelected: Bool
    let expandHorizontally: Bool  // New parameter

    init(
        isSelected: Bool,
        expandHorizontally: Bool = false, // default false
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
            ZStack {
                // Background layers for the button
                Color.white.opacity(isSelected ? 0.95 : 0.4)
                    .background(.ultraThickMaterial)
                    .frame(height: 36) // Slightly reduced height for more squared look
                    .cornerRadius(8)   // Much smaller corner radius
                    // Lighter shadow for squared look
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay {
                        // Subtle gradient for depth
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6),
                                .gray.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .cornerRadius(8)
                    }
                    .overlay {
                        // Glassy border
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                    }
                
                // Button label
                label()
                    .foregroundColor(.black)
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 36)
        }
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// [The rest of the file remains unchanged below...]
private struct ColorPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension UIImage {
    func cropToFrame(_ frame: CGRect) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let scaledFrame = CGRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
        guard let croppedCGImage = cgImage.cropping(to: scaledFrame) else { return self }
        return UIImage(cgImage: croppedCGImage)
    }
    
    func averageColor() -> UIColor {
        guard let inputImage = CIImage(image: self) else { return .white }
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                  y: inputImage.extent.origin.y,
                                  z: inputImage.extent.size.width,
                                  w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: inputImage,
                                             kCIInputExtentKey: extentVector]) else { return .white }
        guard let outputImage = filter.outputImage else { return .white }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
}

extension UIColor {
    func getBrightness() -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Using perceived brightness formula
        return ((red * 299) + (green * 587) + (blue * 114)) / 1000
    }
}

#Preview {
    VStack(spacing: 20) {
        // Default state
        AdaptiveColorButton(isSelected: false) {
            
        } label: {
            Text("Default Button")
        }
        
        // Selected state
        AdaptiveColorButton(isSelected: true) {
            
        } label: {
            Text("Selected Button")
        }
        
        // Long text
        AdaptiveColorButton(isSelected: false) {
            
        } label: {
            Text("Button with Longer Text")
        }
        
        // With SF Symbol
        AdaptiveColorButton(isSelected: false) {
            
        } label: {
            HStack {
                Image(systemName: "star.fill")
                Text("Icon Button")
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity)  // <-- Add this to show alignment
    .background(Color.black) // Dark background to match app context
}