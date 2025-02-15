import SwiftUI

struct ProcessingProgressView: View {
    let currentState: ProcessingState
    @State private var borderProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Border animation
            BorderAnimation(progress: borderProgress, startPosition: .topMiddle, clockwise: true)
                .stroke(Color.yellow, lineWidth: 6)
                .edgesIgnoringSafeArea(.all)
            
            // Status steps
            VStack(spacing: 24) {
                ForEach(ProcessingState.allSteps, id: \.state) { step in
                    StepView(
                        message: step.message,
                        isCompleted: currentState.stepIndex > step.state.stepIndex,
                        isActive: currentState.stepIndex == step.state.stepIndex
                    )
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                borderProgress = 1.0
            }
        }
    }
}

struct StepView: View {
    let message: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.black)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                }
            }
            
            Text(message)
                .foregroundColor(textColor)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(opacity)
    }
    
    private var backgroundColor: Color {
        if isCompleted { return .yellow }
        if isActive { return .yellow.opacity(0.7) }
        return .gray.opacity(0.3)
    }
    
    private var textColor: Color {
        if isCompleted || isActive { return .white }
        return .gray
    }
    
    private var opacity: Double {
        if isCompleted || isActive { return 1.0 }
        return 0.6
    }
} 