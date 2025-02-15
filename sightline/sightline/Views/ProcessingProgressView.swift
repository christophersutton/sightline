import SwiftUI

struct ProcessingProgressView: View {
    let currentState: ProcessingState
    @Environment(\.dismiss) private var dismiss
    @State private var borderProgress: CGFloat = 0
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            if currentState.isErrorState {
                // Error View
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(currentState.errorMessage)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                            .foregroundColor(.black)
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .transition(.opacity)
                }
                .transition(.opacity)
            } else {
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
                            isActive: currentState.stepIndex == step.state.stepIndex,
                            isError: currentState.isErrorState
                        )
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .onChange(of: currentState.isErrorState) { isError in
            withAnimation(.easeInOut(duration: 0.3)) {
                showError = isError
            }
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
    let isError: Bool
    
    init(message: String, isCompleted: Bool, isActive: Bool, isError: Bool = false) {
        self.message = message
        self.isCompleted = isCompleted
        self.isActive = isActive
        self.isError = isError
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if isError {
                    Image(systemName: "exclamationmark")
                        .foregroundColor(.black)
                } else if isCompleted {
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
        if isError { return .red }
        if isCompleted { return .yellow }
        if isActive { return .yellow.opacity(0.7) }
        return .gray.opacity(0.3)
    }
    
    private var textColor: Color {
        if isError { return .red }
        if isCompleted || isActive { return .white }
        return .gray
    }
    
    private var opacity: Double {
        if isCompleted || isActive || isError { return 1.0 }
        return 0.6
    }
} 