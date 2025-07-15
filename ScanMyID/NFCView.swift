//

import SwiftUI
import NFCPassportReader
import CoreNFC

struct NFCView: View {
    let mrzData: String
    let onComplete: () -> Void
    
    @State private var readingState: ReadingState = .ready
    @State private var statusMessage = "Hold your document flat against your device"
    @State private var progressValue: Double = 0.0
    @State private var passportData: PassportData?
    @State private var errorMessage: String?
    
    enum ReadingState {
        case ready
        case connecting
        case authenticating
        case readingPersonalData
        case readingPhoto
        case completed
        case failed
    }
    
    // MARK: - NFC Progress Handler
    
    private func handleNFCDisplayMessage(_ message: NFCViewDisplayMessage) {
        print("📱 NFC Progress: \(message)")
        
        switch message {
        case .requestPresentPassport:
            readingState = .connecting
            statusMessage = "Hold your passport against the device"
            progressValue = 0.2
            
        case .authenticatingWithPassport(let progress):
            readingState = .authenticating
            statusMessage = "Authenticating with passport..."
            progressValue = 0.3 + (Double(progress) * 0.2) // 0.3 to 0.5
            
        case .readingDataGroupProgress(let dataGroup, let progress):
            if dataGroup == .DG1 {
                readingState = .readingPersonalData
                statusMessage = "Reading personal data..."
                progressValue = 0.6 + (Double(progress) * 0.15) // 0.6 to 0.75
            } else if dataGroup == .DG2 {
                readingState = .readingPhoto
                statusMessage = "Reading biometric photo..."
                progressValue = 0.75 + (Double(progress) * 0.15) // 0.75 to 0.9
            } else {
                statusMessage = "Reading \(dataGroup.getName())..."
                progressValue = min(progressValue + 0.05, 0.9)
            }
            
        case .successfulRead:
            readingState = .completed
            statusMessage = "Reading completed successfully!"
            progressValue = 1.0
            
        case .error(let error):
            handleNFCError(error)
            
        default:
            // Handle other message types if needed
            break
        }
    }
    
    // MARK: - NFC Success Handler
    
    private func handleNFCSuccess(with passportModel: NFCPassportModel) {
        readingState = .completed
        statusMessage = "Reading completed successfully!"
        progressValue = 1.0
        
        // Now we have the actual NFCPassportModel with all the data
        print("✅ NFC Reading Successful!")
        print("🔍 Passport Model: \(passportModel)")
        
        // Extract data from the passport model (we'll improve this based on what we see)
        let personalDetails = PersonalDetails(
            fullName: "From PassportModel", // TODO: Extract from actual model
            nationality: "From PassportModel",
            dateOfBirth: "From PassportModel",
            placeOfBirth: nil,
            sex: "From PassportModel"
        )
        
        self.passportData = PassportData(
            mrzData: MRZParser.parse(self.mrzData)!,
            personalDetails: personalDetails,
            photo: nil, // TODO: Extract from model
            chipAuthSuccess: true, // TODO: Check model status
            readingErrors: []
        )
        
        // Haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    // MARK: - NFC Error Handling
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // NFC Animation
            VStack(spacing: 20) {
                ZStack {
                    // Animated rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 80 + CGFloat(index * 40), height: 80 + CGFloat(index * 40))
                            .scaleEffect(readingState == .connecting || readingState == .authenticating ? 1.2 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: readingState
                            )
                    }
                    
                    // Center NFC icon
                    Image(systemName: iconForState)
                        .font(.system(size: 50))
                        .foregroundColor(colorForState)
                        .scaleEffect(readingState == .completed ? 1.3 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: readingState)
                }
            }
            
            // Status and Progress
            VStack(spacing: 16) {
                Text(statusMessage)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(readingState == .failed ? .red : .primary)
                
                if readingState != .ready && readingState != .failed && readingState != .completed {
                    ProgressView(value: progressValue, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                        .scaleEffect(y: 2)
                        .animation(.easeInOut(duration: 0.3), value: progressValue)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                if readingState == .ready || readingState == .failed {
                    Button(action: startNFCReading) {
                        HStack {
                            Image(systemName: "wave.3.right")
                            Text(readingState == .failed ? "Try Again" : "Start NFC Reading")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                
                if readingState == .completed {
                    Button(action: onComplete) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("View Results")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                // Remove the skip button - force proper flow
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            print("📱 NFC View loaded with MRZ: \(mrzData)")
            // DON'T auto-start NFC - wait for user to tap button
        }
    }
    
    // MARK: - UI Helpers
    
    private var iconForState: String {
        switch readingState {
        case .ready: return "wave.3.right"
        case .connecting: return "wifi"
        case .authenticating: return "key"
        case .readingPersonalData: return "person.text.rectangle"
        case .readingPhoto: return "camera"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
    
    private var colorForState: Color {
        switch readingState {
        case .ready, .connecting, .authenticating, .readingPersonalData, .readingPhoto:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    

    
    private func startNFCReading() {
        // Reset state
        readingState = .connecting
        statusMessage = "Connecting to passport chip..."
        progressValue = 0.1
        errorMessage = nil
        
        // Parse MRZ data first
        guard let parsedMRZ = MRZParser.parse(mrzData) else {
            handleError("Invalid MRZ data. Please scan again.")
            return
        }
        
        print("🔑 Starting NFC with BAC Key: \(parsedMRZ.bacKey)")
        
        // Create passport reader
        let passportReader = PassportReader()
        
        // Use Andy's library with proper NFC session management
        Task {
            do {
                // Update UI to show NFC is starting
                DispatchQueue.main.async {
                    self.readingState = .connecting
                    self.statusMessage = "Starting NFC session..."
                    self.progressValue = 0.1
                }
                
                let passportModel = try await passportReader.readPassport(
                    mrzKey: parsedMRZ.bacKey,
                    tags: [.COM, .DG1, .DG2],
                    customDisplayMessage: { displayMessage in
                        // Handle real-time NFC progress messages
                        DispatchQueue.main.async {
                            self.handleNFCDisplayMessage(displayMessage)
                        }
                        return nil // Use default messages
                    }
                )
                
                DispatchQueue.main.async {
                    self.handleNFCSuccess(with: passportModel)
                }
            } catch {
                DispatchQueue.main.async {
                    if let nfcError = error as? NFCPassportReaderError {
                        self.handleNFCError(nfcError)
                    } else {
                        self.handleError("NFC reading failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Simulate progress updates
        simulateProgress()
    }
    
    private func simulateProgress() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if readingState == .connecting {
                readingState = .authenticating
                statusMessage = "Authenticating with passport..."
                progressValue = 0.3
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if readingState == .authenticating {
                        readingState = .readingPersonalData
                        statusMessage = "Reading personal data..."
                        progressValue = 0.6
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if readingState == .readingPersonalData {
                                readingState = .readingPhoto
                                statusMessage = "Reading biometric photo..."
                                progressValue = 0.9
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleNFCResult(passport: NFCPassportModel?, error: NFCPassportReaderError?) {
        if let error = error {
            handleNFCError(error)
            return
        }
        
        guard let passport = passport else {
            handleError("No passport data received")
            return
        }
        
        // Success! Process the passport data
        processPassportData(passport)
    }
    
    private func processPassportData(_ passport: NFCPassportModel) {
        readingState = .completed
        statusMessage = "Reading completed successfully!"
        progressValue = 1.0
        
        // Extract basic info - we'll improve this once we see what the actual data structure is
        var personalDetails: PersonalDetails?
        if let dg1 = passport.dataGroupsRead[.DG1] as? DataGroup1 {
            // For now, extract basic fields that we know exist
            personalDetails = PersonalDetails(
                fullName: "Extracted from DG1", // We'll fix this once we see the actual structure
                nationality: "Unknown",
                dateOfBirth: "Unknown",
                placeOfBirth: nil,
                sex: "Unknown"
            )
            
            // Debug: print the actual structure so we can fix it
            print("🔍 DG1 Structure: \(dg1)")
            print("🔍 DG1 Type: \(type(of: dg1))")
        }
        
        // Extract photo - simplified approach
        var photo: UIImage?
        if let dg2 = passport.dataGroupsRead[.DG2] as? DataGroup2 {
            // Debug: print the actual structure
            print("🔍 DG2 Structure: \(dg2)")
            print("🔍 DG2 Type: \(type(of: dg2))")
            
            // We'll extract the photo once we see the actual API
            photo = nil // Placeholder for now
        }
        
        // Store the complete passport data
        self.passportData = PassportData(
            mrzData: MRZParser.parse(mrzData)!,
            personalDetails: personalDetails,
            photo: photo,
            chipAuthSuccess: true, // We'll determine this properly later
            readingErrors: []
        )
        
        print("✅ NFC Reading Successful!")
        print("👤 Name: \(personalDetails?.fullName ?? "Unknown")")
        print("🏳️ Nationality: \(personalDetails?.nationality ?? "Unknown")")
        print("📸 Photo: \(photo != nil ? "✅ Extracted" : "❌ Not found")")
        
        // Haptic feedback for success
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    private func handleNFCError(_ error: NFCPassportReaderError) {
        let errorMessage: String
        
        switch error {
        case .ConnectionError:
            errorMessage = "Connection failed. Please hold your passport flat against the device."
        case .InvalidMRZKey:
            errorMessage = "Authentication failed. The MRZ data may be incorrect."
        case .MoreThanOneTagFound:
            errorMessage = "Multiple cards detected. Please use only one document."
        case .NoConnectedTag:
            errorMessage = "No NFC chip detected. Ensure your passport has an NFC chip."
        case .ResponseError(let msg, _, _):
            errorMessage = "Reading error: \(msg)"
        case .InvalidResponse:
            errorMessage = "Invalid response from passport chip."
        case .UnexpectedError:
            errorMessage = "Unexpected error occurred. Please try again."
        case .NFCNotSupported:
            errorMessage = "NFC not supported on this device."
        case .TagNotValid:
            errorMessage = "Invalid passport chip detected."
        default:
            errorMessage = "Unknown error occurred: \(error.localizedDescription)"
        }
        
        handleError(errorMessage)
    }
    
    private func handleNFCInvalidation(reason: String) {
        print("📱 NFC Session invalidated: \(reason)")
        if readingState != .completed {
            handleError("NFC session ended unexpectedly")
        }
    }
    
    private func handleError(_ message: String) {
        readingState = .failed
        statusMessage = "Reading Failed"
        errorMessage = message
        progressValue = 0.0
        
        print("❌ NFC Error: \(message)")
        
        // Haptic feedback for error
        let errorFeedback = UINotificationFeedbackGenerator()
        errorFeedback.notificationOccurred(.error)
    }
}

// MARK: - Data Models

struct PassportData {
    let mrzData: MRZData
    let personalDetails: PersonalDetails?
    let photo: UIImage?
    let chipAuthSuccess: Bool
    let readingErrors: [String]
}

struct PersonalDetails {
    let fullName: String
    let nationality: String
    let dateOfBirth: String
    let placeOfBirth: String?
    let sex: String
}

#Preview {
    NFCView(
        mrzData: "L898902C3UTO7408122F1204159ZE184226B<<<<<10",
        onComplete: {}
    )
}
