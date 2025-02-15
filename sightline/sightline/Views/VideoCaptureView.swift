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
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var currentVideoPath: URL?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let reviewService = VideoReviewService()
    let placeId: String
    private let maxRecordingDuration: TimeInterval = 60 // 1 minute max
    private var currentCamera: AVCaptureDevice.Position = .back
    private var statusListener: ListenerRegistration?
    
    private let videoQueue = DispatchQueue(label: "videoQueue")
    private let audioQueue = DispatchQueue(label: "audioQueue")
    private var sessionStarted = false
    
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
        
        // Configure video output for AVAssetWriter
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            // Add this new code to set orientation
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            
            self.videoOutput = videoOutput
        }
        
        // Configure audio output for AVAssetWriter
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioOutput = audioOutput
        }
        
        self.captureSession = session
        isAuthorized = true
        
        // Start the session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func startRecording() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        currentVideoPath = paths[0].appendingPathComponent("review_video.mp4")
        
        guard let videoPath = currentVideoPath else { return }
        
        // Remove existing file if needed
        try? FileManager.default.removeItem(at: videoPath)
        
        do {
            assetWriter = try AVAssetWriter(url: videoPath, fileType: .mp4)
            
            // Update video settings to include orientation
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,  // Swapped width/height for portrait
                AVVideoHeightKey: 1280, // Swapped width/height for portrait
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2000000,
                    AVVideoMaxKeyFrameIntervalKey: 30,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoExpectedSourceFrameRateKey: 30,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
                ]
            ]
            
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            // Configure audio input
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000 // 128 kbps
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if let assetWriter = assetWriter,
               let videoInput = assetWriterInput,
               let audioInput = audioInput {
                if assetWriter.canAdd(videoInput) {
                    assetWriter.add(videoInput)
                }
                if assetWriter.canAdd(audioInput) {
                    assetWriter.add(audioInput)
                }
                
                sessionStarted = false
                assetWriter.startWriting()
            }
            
            isRecording = true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopRecording() {
        isRecording = false
        
        // Set state to uploading before starting the upload
        processingState = .uploading
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self,
                  let videoPath = self.currentVideoPath else { return }
            
            // Upload the video
            Task {
                do {
                    let reviewId = try await self.reviewService.uploadReview(videoURL: videoPath, placeId: self.placeId)
                    await MainActor.run {
                        self.listenToProcessingUpdates(reviewId: reviewId)
                    }
                } catch {
                    await MainActor.run {
                        self.processingState = .failed
                    }
                }
            }
        }
    }
    
    func switchCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove existing video input
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
        
        // Ensure proper orientation for new camera
        if let videoOutput = self.videoOutput,
           let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentCamera == .front)
            }
        }
        
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

extension VideoCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let assetWriter = assetWriter else { return }
        
        // Start the session with the first video sample
        if !sessionStarted && output == videoOutput {
            sessionStarted = true
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: timestamp)
        }
        
        // Only proceed if session has started
        guard sessionStarted else { return }
        
        if output == videoOutput,
           let input = assetWriterInput,
           input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
        
        if output == audioOutput,
           let input = audioInput,
           input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
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
                ProcessingProgressView(currentState: controller.processingState)
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