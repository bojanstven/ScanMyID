//

import SwiftUI
import NFCPassportReader
import CoreNFC

struct NFCView: View {
    let mrzData: String
    let onComplete: (PassportData) -> Void
    
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
            break
        }
    }
    
    // MARK: - NFC Success Handler - SIMPLIFIED VERSION THAT WORKS
    
    private func handleNFCSuccess(with passportModel: NFCPassportModel) {
        readingState = .completed
        statusMessage = "Reading completed successfully!"
        progressValue = 1.0
        
        print("✅ NFC Reading Successful!")
        print("🔍 Available Data Groups: \(passportModel.dataGroupsRead.keys)")
        
        // Extract MRZ data first
        guard let parsedMRZ = MRZParser.parse(self.mrzData) else {
            handleError("Failed to parse MRZ data")
            return
        }
        
        // Extract personal details using NFCPassportModel convenience properties
        let personalDetails = PersonalDetails(
            fullName: "\(passportModel.firstName ?? "Unknown") \(passportModel.lastName ?? "Unknown")",
            surname: passportModel.lastName ?? "Unknown",
            givenNames: passportModel.firstName ?? "Unknown",
            nationality: passportModel.nationality ?? parsedMRZ.nationality ?? "Unknown",
            dateOfBirth: formatDate(passportModel.dateOfBirth ?? parsedMRZ.dateOfBirth),
            placeOfBirth: passportModel.placeOfBirth,
            sex: passportModel.gender ?? parsedMRZ.sex ?? "Unknown",
            documentNumber: passportModel.documentNumber ?? parsedMRZ.documentNumber,
            documentType: passportModel.documentType ?? "P",
            issuingCountry: parsedMRZ.issuingCountry ?? "Unknown",
            expiryDate: formatDate(passportModel.documentExpiryDate ?? parsedMRZ.expiryDate)
        )
        
        print("👤 Name: \(personalDetails.fullName)")
        print("🏳️ Nationality: \(personalDetails.nationality)")
        print("📅 DOB: \(personalDetails.dateOfBirth)")
        print("🆔 Document: \(personalDetails.documentNumber)")
        
        // Extract photo using NFCPassportModel convenience property
        var photo: UIImage?
        if let passportImage = passportModel.passportImage {
            photo = passportImage
            print("✅ Photo extracted successfully")
        } else {
            print("❌ No photo found")
        }
        
        // Collect additional information that's available
        var additionalInfo: [String: String] = [:]
        
        if let personalNumber = passportModel.personalNumber {
            additionalInfo["Personal Number"] = personalNumber
        }
        if let phoneNumber = passportModel.phoneNumber {
            additionalInfo["Phone Number"] = phoneNumber
        }
        
        // Create comprehensive passport data
        let finalPassportData = PassportData(
            mrzData: parsedMRZ,
            personalDetails: personalDetails,
            photo: photo,
            additionalInfo: additionalInfo,
            chipAuthSuccess: passportModel.passportCorrectlySigned,
            bacSuccess: passportModel.BACStatus == .success,
            readingErrors: passportModel.verificationErrors.map { $0.localizedDescription }
        )
        
        self.passportData = finalPassportData
        
        print("✅ Data extraction completed!")
        print("🔐 BAC Success: \(finalPassportData.bacSuccess)")
        print("🔒 Chip Auth: \(finalPassportData.chipAuthSuccess)")
        print("📸 Photo: \(photo != nil ? "✅ Extracted" : "❌ Not found")")
        print("📋 Additional Info: \(additionalInfo.count) fields")
        print("❌ Verification Errors: \(finalPassportData.readingErrors.count)")
        
        // Log all the raw data we got for debugging
        print("🔍 RAW NFCPassportModel Debug Info:")
        print("   - firstName: \(passportModel.firstName ?? "nil")")
        print("   - lastName: \(passportModel.lastName ?? "nil")")
        print("   - documentNumber: \(passportModel.documentNumber ?? "nil")")
        print("   - nationality: \(passportModel.nationality ?? "nil")")
        print("   - dateOfBirth: \(passportModel.dateOfBirth ?? "nil")")
        print("   - documentExpiryDate: \(passportModel.documentExpiryDate ?? "nil")")
        print("   - gender: \(passportModel.gender ?? "nil")")
        print("   - documentType: \(passportModel.documentType ?? "nil")")
        print("   - issuingCountry: \(parsedMRZ.issuingCountry ?? "nil")")
        print("   - placeOfBirth: \(passportModel.placeOfBirth ?? "nil")")
        print("   - personalNumber: \(passportModel.personalNumber ?? "nil")")
        print("   - phoneNumber: \(passportModel.phoneNumber ?? "nil")")
        print("   - passportImage: \(passportModel.passportImage != nil ? "✅ Present" : "❌ Nil")")
        print("   - passportCorrectlySigned: \(passportModel.passportCorrectlySigned)")
        print("   - BACStatus: \(passportModel.BACStatus)")
        
        // Haptic feedback for success
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        // Return data to parent
        onComplete(finalPassportData)
    }
    
    // MARK: - Date Formatting Helper
    
    private func formatDate(_ dateString: String) -> String {
        // Handle YYMMDD format from MRZ
        if dateString.count == 6 {
            let year = String(dateString.prefix(2))
            let month = String(dateString.dropFirst(2).prefix(2))
            let day = String(dateString.dropFirst(4))
            
            // Convert YY to YYYY (assuming 00-30 is 2000s, 31-99 is 1900s)
            let fullYear = Int(year)! <= 30 ? "20\(year)" : "19\(year)"
            
            return "\(day)/\(month)/\(fullYear)"
        }
        
        // Return as-is if not in expected format
        return dateString
    }
    
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
                
                if readingState == .completed && passportData != nil {
                    Button(action: {
                        if let data = passportData {
                            onComplete(data)
                        }
                    }) {
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            print("📱 NFC View loaded with MRZ: \(mrzData)")
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
        
        // Read all available data groups for comprehensive extraction
        Task {
            do {
                DispatchQueue.main.async {
                    self.readingState = .connecting
                    self.statusMessage = "Starting NFC session..."
                    self.progressValue = 0.1
                }
                
                let passportModel = try await passportReader.readPassport(
                    mrzKey: parsedMRZ.bacKey,
                    tags: [.COM, .DG1, .DG2, .DG11, .DG12, .DG13, .DG14, .DG15], // Read comprehensive data
                    customDisplayMessage: { displayMessage in
                        DispatchQueue.main.async {
                            self.handleNFCDisplayMessage(displayMessage)
                        }
                        return nil
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

#Preview {
    NFCView(
        mrzData: "L898902C3UTO7408122F1204159ZE184226B<<<<<10",
        onComplete: { _ in }
    )
}
