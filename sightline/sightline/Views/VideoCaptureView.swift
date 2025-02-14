import SwiftUI
import AVFoundation
import FirebaseFirestore

class VideoCaptureController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isRecording = false
    @Published var error: String?
    @Published var isUploading = false
    @Published var shouldDismiss = false
    @Published var uploadProgress: Double = 0
    @Published var processingState: ProcessingState = .notStarted
    
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let reviewService = VideoReviewService()
    let placeId: String
    private let maxRecordingDuration: TimeInterval = 60 // 1 minute max
    private var currentCamera: AVCaptureDevice.Position = .back
    private var statusListener: ListenerRegistration?
    
    init(placeId: String) {
        self.placeId = placeId
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            error = "Camera access denied"
        @unknown default:
            error = "Unknown authorization status"
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        // Configure video input
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            error = "Failed to setup video capture"
            return
        }
        session.addInput(videoInput)
        
        // Configure audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioInput) else {
            error = "Failed to setup audio capture"
            return
        }
        session.addInput(audioInput)
        
        // Configure video output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.videoOutput = movieOutput
        }
        
        self.captureSession = session
        isAuthorized = true
        
        // Start the session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func startRecording() {
        guard let output = videoOutput else { return }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("review_video.mp4")
        
        try? FileManager.default.removeItem(at: fileUrl)
        
        // Set max duration
        output.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
        output.startRecording(to: fileUrl, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
    }
    
    func switchCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove only video input
        let videoInput = session.inputs.first { input in
            (input as? AVCaptureDeviceInput)?.device.hasMediaType(.video) ?? false
        }
        if let videoInput = videoInput {
            session.removeInput(videoInput)
        }
        
        // Switch to opposite camera
        currentCamera = currentCamera == .front ? .back : .front
        
        // Add new video input
        let devicePosition: AVCaptureDevice.Position = currentCamera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            error = "Failed to switch camera"
            session.commitConfiguration()
            return
        }
        
        session.addInput(videoInput)
        session.commitConfiguration()
    }
    
    private func listenToProcessingUpdates(reviewId: String) {
        // Clean up any existing listener
        statusListener?.remove()
        
        // Set up new listener
        statusListener = reviewService.listenToProcessingStatus(reviewId: reviewId) { [weak self] status in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.processingState = status
                
                // If complete, wait a moment before dismissing
                if status == .complete {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.shouldDismiss = true
                    }
                }
            }
        }
    }
    
    deinit {
        statusListener?.remove()
    }
}

extension VideoCaptureController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isRecording = false
        
        if let error = error {
            self.error = error.localizedDescription
            return
        }
        
        // Set state to uploading before starting the upload
        processingState = .uploading
        
        Task {
            do {
                let reviewId = try await reviewService.uploadReview(videoURL: outputFileURL, placeId: placeId)
                
                // Start listening for processing updates
                listenToProcessingUpdates(reviewId: reviewId)
                
            } catch {
                await MainActor.run {
                    processingState = .failed
                }
            }
        }
    }
}

struct VideoCapturePreviewView: UIViewRepresentable {
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

struct VideoCaptureView: View {
    @StateObject private var controller: VideoCaptureController
    @Environment(\.dismiss) private var dismiss
    
    init(placeId: String) {
        _controller = StateObject(wrappedValue: VideoCaptureController(placeId: placeId))
    }
    
    var body: some View {
        ZStack {
            if case .notStarted = controller.processingState {
                // Only show camera view when not processing
                if let session = controller.captureSession {
                    VideoCapturePreviewView(session: session)
                    
                    VStack {
                        Spacer()
                        
                        // Control buttons at bottom
                        HStack {
                            // Close button
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            
                            Spacer()
                            
                            // Record button
                            Button(action: {
                                if controller.isRecording {
                                    controller.stopRecording()
                                } else {
                                    controller.startRecording()
                                }
                            }) {
                                Image(systemName: controller.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.system(size: 72))
                                    .foregroundColor(controller.isRecording ? .red : .white)
                            }
                            
                            Spacer()
                            
                            // Camera flip button
                            Button(action: { controller.switchCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            } else {
                // Processing screen
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProcessingStatusView(state: controller.processingState)
                        
                        // Optional cancel button
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            if let error = controller.error {
                Text(error)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .ignoresSafeArea()
        .onChange(of: controller.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }
}

struct ProcessingStatusView: View {
    let state: ProcessingState
    
    var body: some View {
        VStack(spacing: 8) {
            // Show progress indicator for any non-terminal state
            if case .uploading = state {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            Text(state.description)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
        }
    }
} 