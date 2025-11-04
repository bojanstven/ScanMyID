//

import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    let onMRZScanned: (String) -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview - Fullscreen on top, respects bottom safe area for TabView
            CameraPreview(onMRZScanned: onMRZScanned)
                .ignoresSafeArea(.all, edges: .top)  // Only ignore TOP safe area
                // This keeps TabView visible at bottom while camera goes fullscreen on top
            
            // Bottom Overlay - Positioned above TabView
            VStack {
                Spacer()
                
                VStack(spacing: 30) {
                    // Document type icons - aligned with text below
                    HStack {
                        VStack(spacing: 8) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 65))
                                .foregroundColor(.blue)
                            Text("Passport")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 65))
                                .foregroundColor(.blue)
                            Text("ID card")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Text("Scan the data page of your passport or the back of your ID card")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.65))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let onMRZScanned: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Start camera setup immediately but properly
        setupCamera(view: view, context: context)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure preview layer frame is updated when view bounds change
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                // Only update if bounds have actually changed
                if !previewLayer.frame.equalTo(uiView.bounds) {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    previewLayer.frame = uiView.bounds
                    CATransaction.commit()
                }
            }
        }
    }
    
    private func setupCamera(view: UIView, context: Context) {
        // Check camera permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCameraSession(view: view, context: context)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.configureCameraSession(view: view, context: context)
                    }
                }
            }
        default:
            print("❌ Camera access denied")
            return
        }
    }
    
    private func configureCameraSession(view: UIView, context: Context) {
        // Get the best back camera available
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
                          AVCaptureDevice.default(for: .video) else {
            print("❌ No camera found")
            return
        }
        
        print("✅ Using camera: \(camera.localizedName)")
        
        let session = AVCaptureSession()
        
        // Use highest quality for best OCR results
        session.sessionPreset = .photo
        
        do {
            // Create and add input
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("❌ Cannot add camera input")
                return
            }
            
            // Create and configure output
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "camera.processing", qos: .userInitiated))
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                print("❌ Cannot add camera output")
                return
            }
            
            // Store session in coordinator FIRST
            context.coordinator.session = session
            
            // Create preview layer and configure it properly
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            // Store preview layer in coordinator
            context.coordinator.previewLayer = previewLayer
            
            // Add preview layer to view on main thread
            DispatchQueue.main.async {
                // Ensure view still exists and has proper bounds
                guard view.bounds.width > 0 && view.bounds.height > 0 else {
                    // Wait a bit and try again if view isn't ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.addPreviewLayerToView(view: view, previewLayer: previewLayer)
                    }
                    return
                }
                
                self.addPreviewLayerToView(view: view, previewLayer: previewLayer)
            }
            
            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    print("✅ Camera session started")
                }
            }
            
        } catch {
            print("❌ Camera setup error: \(error)")
        }
    }
    
    private func addPreviewLayerToView(view: UIView, previewLayer: AVCaptureVideoPreviewLayer) {
        // Remove any existing preview layers first
        view.layer.sublayers?.removeAll { $0 is AVCaptureVideoPreviewLayer }
        
        // Set frame and add to view
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        
        print("✅ Preview layer added with frame: \(previewLayer.frame)")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // Clean shutdown
        coordinator.session?.stopRunning()
        coordinator.previewLayer?.removeFromSuperlayer()
        coordinator.session = nil
        coordinator.previewLayer = nil
        print("🧹 Camera cleaned up")
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let parent: CameraPreview
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var isScanning = true
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Stop processing if we already found MRZ
            guard isScanning else { return }
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            let request = VNRecognizeTextRequest { (request, error) in
                // Double-check we're still scanning to prevent race conditions
                guard self.isScanning else { return }
                
                if let _ = error {
                    return // Silent error handling
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                // Look for MRZ pattern and return ONLY the MRZ lines
                if self.isMRZPattern(recognizedText) {
                    // IMMEDIATELY stop scanning to prevent duplicate reads
                    self.isScanning = false
                    
                    let mrzLines = self.extractMRZLines(from: recognizedText)
                    print("✅ MRZ DETECTED - STOPPING SCAN")
                    print("📄 Final MRZ:")
                    print(mrzLines)
                    print("")
                    
                    // Let MRZParser handle all the parsing and logging
                    _ = MRZParser.parse(mrzLines)
                    
                    DispatchQueue.main.async {
                        // Stop camera session first
                        self.session?.stopRunning()
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Return the MRZ data
                        self.parent.onMRZScanned(mrzLines)
                    }
                }
            }
            
            // High accuracy settings for best OCR
            if #available(iOS 16.0, *) {
                request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
                request.automaticallyDetectsLanguage = false
            } else {
                request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
            }
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.03 // Smaller for iOS 16 compatibility
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                // Silent error handling
            }
        }
        
        private func extractMRZLines(from text: String) -> String {
            let lines = text.components(separatedBy: .newlines)
            
            for line in lines {
                let cleanLine = line.replacingOccurrences(of: " ", with: "").uppercased()
                
                // Extract passport MRZ line 2: Document details (the important one)
                if cleanLine.count >= 40 &&
                   cleanLine.contains("<") &&
                   cleanLine.filter({ $0.isNumber }).count >= 8 {
                    // Return just the data line - that's all we need for BAC key
                    return cleanLine
                }
            }
            
            return ""
        }
        
        private func isMRZPattern(_ text: String) -> Bool {
            let lines = text.components(separatedBy: .newlines)
            
            for line in lines {
                let cleanLine = line.replacingOccurrences(of: " ", with: "").uppercased()
                
                // Skip short lines
                if cleanLine.count < 40 {
                    continue
                }
                
                // ONLY CHECK LINE 2: Document number + birth date + expiry + etc.
                if cleanLine.count >= 40 &&
                   cleanLine.filter({ $0.isNumber }).count >= 8 &&
                   cleanLine.filter({ $0.isLetter }).count >= 3 &&
                   cleanLine.contains("<") {
                    return true // No logging - just return true
                }
            }
            
            return false // No logging for failures either
        }
    }
}

#Preview {
    CameraView(onMRZScanned: { mrz in
        print("MRZ: \(mrz)")
    })
}
