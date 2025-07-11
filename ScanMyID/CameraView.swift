//

import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    let onMRZScanned: (String) -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(onMRZScanned: onMRZScanned)
                .ignoresSafeArea()
            
            // Bottom Overlay
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
                    .padding(.horizontal, 20) // This ensures alignment with text below
                    
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
                .padding(.bottom, 40)
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let onMRZScanned: (String) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        setupCamera(view: view, context: context)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    private func setupCamera(view: UIView, context: Context) {
        // Simple: just get the default back camera
        guard let camera = AVCaptureDevice.default(for: .video) else {
            print("❌ No camera found")
            return
        }
        
        print("✅ Using camera: \(camera.localizedName)")
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo // Highest quality for accurate OCR
        
        // Create input
        guard let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("❌ Cannot create camera input")
            return
        }
        session.addInput(input)
        
        // Create output with iOS 16 compatibility
        let output = AVCaptureVideoDataOutput()
        
        // Better settings for older devices
        if #available(iOS 17.0, *) {
            output.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "camera"))
        } else {
            // iOS 16 - use lower priority queue to prevent overload
            let queue = DispatchQueue(label: "camera", qos: .userInitiated)
            output.setSampleBufferDelegate(context.coordinator, queue: queue)
        }
        
        guard session.canAddOutput(output) else {
            print("❌ Cannot add camera output")
            return
        }
        session.addOutput(output)
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Store in coordinator
        context.coordinator.session = session
        context.coordinator.previewLayer = previewLayer
        
        // Start session
        DispatchQueue.global().async {
            session.startRunning()
            print("✅ Camera started")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
        coordinator.session = nil
        coordinator.previewLayer?.removeFromSuperlayer()
        coordinator.previewLayer = nil
        print("🧹 Camera cleaned up")
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let parent: CameraPreview
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var isScanning = true // Add scanning state
        
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
