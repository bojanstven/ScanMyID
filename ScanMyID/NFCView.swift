import SwiftUI
import NFCPassportReader
import CoreNFC

struct NFCView: View {
    let mrzData: String
    let onComplete: (PassportData) -> Void
    
    @State private var readingState: ReadingState = .ready
    @State private var statusMessage = "Hold your phone flat against the top of the passport, with no gap between the two items."
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
            fullName: "\(passportModel.firstName) \(passportModel.lastName)",
            surname: passportModel.lastName,
            givenNames: passportModel.firstName,
            nationality: passportModel.nationality.isEmpty ? parsedMRZ.nationality ?? "Unknown" : passportModel.nationality,
            dateOfBirth: formatDate(passportModel.dateOfBirth.isEmpty ? parsedMRZ.dateOfBirth : passportModel.dateOfBirth),
            placeOfBirth: passportModel.placeOfBirth,  // This one IS String? (optional)
            sex: passportModel.gender.isEmpty ? parsedMRZ.sex ?? "Unknown" : passportModel.gender,
            documentNumber: passportModel.documentNumber.isEmpty ? parsedMRZ.documentNumber : passportModel.documentNumber,
            documentType: passportModel.documentType,
            issuingCountry: parsedMRZ.issuingCountry ?? "Unknown",
            expiryDate: formatDate(passportModel.documentExpiryDate.isEmpty ? parsedMRZ.expiryDate : passportModel.documentExpiryDate)
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
        print("   - firstName: \(passportModel.firstName)")
        print("   - lastName: \(passportModel.lastName)")
        print("   - documentNumber: \(passportModel.documentNumber)")
        print("   - nationality: \(passportModel.nationality)")
        print("   - dateOfBirth: \(passportModel.dateOfBirth)")
        print("   - documentExpiryDate: \(passportModel.documentExpiryDate)")
        print("   - gender: \(passportModel.gender)")
        print("   - documentType: \(passportModel.documentType)")
        print("   - issuingCountry: \(parsedMRZ.issuingCountry ?? "Unknown")")
        print("   - placeOfBirth: \(passportModel.placeOfBirth ?? "nil")")  // This one IS optional
        print("   - personalNumber: \(passportModel.personalNumber ?? "nil")")  // This one IS optional
        print("   - phoneNumber: \(passportModel.phoneNumber ?? "nil")")  // This one IS optional
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
            
            // MARK: - NEW STATIC NFC Section (The Solution)

            
            VStack(spacing: 30) {
                // Static NFC icon
                Image(systemName: "wave.3.up.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(colorForState)
                
            }

            
            // Status and Progress
            VStack(spacing: 16) {
                Text(statusMessage)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(readingState == .failed ? .red : .primary)
                    .padding(.horizontal, 20)
                
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
                    tags: [.COM, .SOD, .DG1, .DG2, .DG11, .DG12, .DG13, .DG14, .DG15], // Added .SOD for digital signature
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
