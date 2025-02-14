import SwiftUI
import AVFoundation
import CoreHaptics

class CameraController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var error: String?
    @Published var isCapturing = false
    
    var captureSession: AVCaptureSession?
    private var videoOutput = AVCaptureVideoDataOutput()
    private(set) var frameCount = 0
    private let maxFrames = 10
    private var captureStartTime: Date?
    private var lastCaptureTime: Date?
    private var onFrameCaptured: ((UIImage) -> Void)?
    private var onCaptureCompleted: (() -> Void)?
    
    private var hasCompletedCapture = false
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            self.isAuthorized = false
            self.error = "Camera access is denied. Please enable it in Settings."
        @unknown default:
            self.isAuthorized = false
            self.error = "Unknown camera authorization status"
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Failed to initialize camera"
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        captureSession = session
    }
    
    func startCapturing(onFrameCaptured: @escaping (UIImage) -> Void, onCaptureCompleted: @escaping () -> Void) {
        self.onFrameCaptured = onFrameCaptured
        self.frameCount = 0
        self.lastCaptureTime = nil
        self.captureStartTime = Date()
        self.isCapturing = true
        self.onCaptureCompleted = onCaptureCompleted
        self.hasCompletedCapture = false
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopCapturing() {
        guard !hasCompletedCapture else { return }
        
        hasCompletedCapture = true
        self.isCapturing = false
        self.onFrameCaptured = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.onCaptureCompleted?()
            }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCapturing && frameCount < maxFrames else { return }
        
        let now = Date()
        
        if frameCount == 0 {
            guard let startTime = captureStartTime, now.timeIntervalSince(startTime) >= 3.0 else {
                return
            }
        } else {
            let requiredInterval: TimeInterval = frameCount < 5 ? 1.0 : 2.0
            guard let lastTime = lastCaptureTime, now.timeIntervalSince(lastTime) >= requiredInterval else {
                return
            }
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let onFrameCaptured = onFrameCaptured else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.frameCount += 1
            self.lastCaptureTime = now
            onFrameCaptured(image)
            
            if self.frameCount >= self.maxFrames {
                self.stopCapturing()
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// Updated CameraView with flash overlay effect added.
// sightline/sightline/Views/CameraView.swift
import SwiftUI
import AVFoundation
import CoreHaptics

struct CameraView: View {
    @StateObject private var cameraController = CameraController()
    @Environment(\.dismiss) private var dismiss
    var onFrameCaptured: (UIImage) -> Void
    @Binding var shouldFlash: Bool

    @State private var flashOverlayOpacity: Double = 0.0
    @EnvironmentObject var landmarkDetectionStore: LandmarkDetectionStore // Use the store
    @State private var hapticEngine: CHHapticEngine?
    @State private var successMessage: String?
    @Namespace private var namespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let session = cameraController.captureSession {
                    CameraPreviewView(session: session)

                    // Status Messages (Modified for LandmarkDetectionStore)
                    if let message = successMessage {
                        Text(message)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.yellow.opacity(0.7))
                            .cornerRadius(10)
                            .transition(.opacity)
                    } else if let error = cameraController.error {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }

                    // Flash overlay effect (Keep this)
                    Color.white
                        .opacity(flashOverlayOpacity)
                        .ignoresSafeArea()

                    // Scanning Animation (Modified for LandmarkDetectionStore)
                    if cameraController.isCapturing && !shouldFlash && !landmarkDetectionStore.isCapturing {
                        ScanningAnimation(namespace: namespace)
                            .ignoresSafeArea()
                    }
                }
            }
            .ignoresSafeArea(.all, edges: .all)
            .onChange(of: shouldFlash) { newValue in
                if newValue {
                    playHapticSuccess()
                    withAnimation(.easeIn(duration: 0.1)) {
                        flashOverlayOpacity = 1.0
                        successMessage = "Landmark Found!"
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                        flashOverlayOpacity = 0.0
                    }
                }
            }
            .onAppear {
                prepareHaptics()
                landmarkDetectionStore.startCapture() // Use store's method
                cameraController.startCapturing(
                    onFrameCaptured: { image in
                        onFrameCaptured(image)
                    },
                    onCaptureCompleted: {
                        landmarkDetectionStore.captureCompleted() // Use store's method
                    }
                )
            }
            .onDisappear {
                cameraController.stopCapturing()
            }
        }
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptics error: \(error)")
        }
    }

    private func playHapticSuccess() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }

        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}
#if DEBUG
// Mock preview view that replaces camera feed with a color
private struct MockCameraPreviewView: View {
    var body: some View {
        Color.gray // Simulates camera view
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(
            onFrameCaptured: { _ in },
            shouldFlash: .constant(false)
        )
        .previewDisplayName("Camera View")
        
        // Preview with flash effect
        CameraView(
            onFrameCaptured: { _ in },
            shouldFlash: .constant(true)
        )
        .previewDisplayName("With Flash")
    }
}
#endif 
