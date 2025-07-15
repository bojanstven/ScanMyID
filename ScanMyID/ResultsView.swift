//

import SwiftUI

struct ResultsView: View {
    let passportData: PassportData
    let onScanAnother: () -> Void
    @State private var showingSaveSuccess = false
    @State private var showingSavedScans = false
    @State private var isPhotoFullScreen = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Scan Results")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: passportData.isAuthenticated ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                            Text(passportData.isAuthenticated ? "Authenticated" : "Read Only")
                                .font(.caption)
                                .foregroundColor(passportData.isAuthenticated ? .green : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Photo section
                    if let photo = passportData.photo {
                        Button(action: { isPhotoFullScreen = true }) {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 100)
                            .cornerRadius(8)
                            .overlay(
                                VStack {
                                    Image(systemName: "person.crop.rectangle")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("No Photo")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
                .padding(.horizontal, 20)
                
                // Personal Information
                if let personalDetails = passportData.personalDetails {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            DataRow(label: "Full Name", value: personalDetails.fullName)
                            DataRow(label: "Given Names", value: personalDetails.givenNames)
                            DataRow(label: "Surname", value: personalDetails.surname)
                            DataRow(label: "Nationality", value: personalDetails.nationality)
                            DataRow(label: "Date of Birth", value: personalDetails.dateOfBirth)
                            DataRow(label: "Sex", value: personalDetails.sex)
                            
                            if let placeOfBirth = personalDetails.placeOfBirth {
                                DataRow(label: "Place of Birth", value: placeOfBirth)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Document Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Information")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        DataRow(label: "Document Type", value: passportData.personalDetails?.documentType ?? passportData.mrzData.documentType ?? "Unknown")
                        DataRow(label: "Document Number", value: passportData.personalDetails?.documentNumber ?? passportData.mrzData.documentNumber)
                        DataRow(label: "Issuing Country", value: passportData.personalDetails?.issuingCountry ?? passportData.mrzData.issuingCountry ?? "Unknown")
                        DataRow(label: "Expiry Date", value: passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // Additional Information (if available)
                if !passportData.additionalInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Information")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 1) {
                            ForEach(Array(passportData.additionalInfo.keys.sorted()), id: \.self) { key in
                                DataRow(label: key, value: passportData.additionalInfo[key] ?? "")
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Security Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Security & Verification")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 1) {
                        SecurityRow(label: "BAC Authentication", success: passportData.bacSuccess)
                        SecurityRow(label: "Chip Authentication", success: passportData.chipAuthSuccess)
                        SecurityRow(label: "Digital Signature", success: passportData.isAuthenticated)
                        DataRow(label: "Reading Date", value: DateFormatter.shortDateTime.string(from: passportData.readingDate))
                        
                        if !passportData.readingErrors.isEmpty {
                            ForEach(passportData.readingErrors.prefix(3), id: \.self) { error in
                                DataRow(label: "Error", value: error)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                
                // MRZ Data (Technical)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Technical Data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("MRZ")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(passportData.mrzData.rawMRZ)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                }
                .padding(.horizontal, 20)
                
                // Action Buttons
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Button(action: saveData) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: { showingSavedScans = true }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("History")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: onScanAnother) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Scan Another Document")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $isPhotoFullScreen) {
            if let photo = passportData.photo {
                PhotoFullScreenView(photo: photo)
            }
        }
        .sheet(isPresented: $showingSavedScans) {
            SavedScansView()
        }
        .alert("Data Saved", isPresented: $showingSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your passport data has been saved locally and securely.")
        }
        .onAppear {
            print("📱 Results screen loaded with passport data")
            print("👤 Name: \(passportData.personalDetails?.fullName ?? "Unknown")")
            print("🏳️ Nationality: \(passportData.personalDetails?.nationality ?? "Unknown")")
            print("📸 Photo: \(passportData.hasPhoto ? "Yes" : "No")")
            print("🔐 Authenticated: \(passportData.isAuthenticated ? "Yes" : "No")")
        }
    }
    
    private func saveData() {
        let success = PassportDataStorage.savePassportData(passportData)
        if success {
            showingSaveSuccess = true
            
            // Haptic feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct SecurityRow: View {
    let label: String
    let success: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? .green : .red)
                Text(success ? "Verified" : "Failed")
                    .fontWeight(.medium)
                    .foregroundColor(success ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct PhotoFullScreenView: View {
    let photo: UIImage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }
            .navigationTitle("Biometric Photo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct SavedScansView: View {
    @State private var savedScans = PassportDataStorage.loadSavedScans()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if savedScans.isEmpty {
                    VStack {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No saved scans")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Your saved passport scans will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(savedScans.reversed(), id: \.id) { scan in
                        SavedScanRow(scan: scan)
                    }
                    .onDelete(perform: deleteScans)
                }
            }
            .navigationTitle("Saved Scans")
            .navigationBarItems(
                leading: Button("Clear All") {
                    PassportDataStorage.clearAllData()
                    savedScans.removeAll()
                }.foregroundColor(.red),
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            savedScans = PassportDataStorage.loadSavedScans()
        }
    }
    
    private func deleteScans(at offsets: IndexSet) {
        let reversedScans = savedScans.reversed()
        for index in offsets {
            let scanToDelete = Array(reversedScans)[index]
            PassportDataStorage.deleteScan(scanToDelete)
        }
        savedScans = PassportDataStorage.loadSavedScans()
    }
}

struct SavedScanRow: View {
    let scan: SavedPassportScan
    
    var body: some View {
        HStack {
            // Photo thumbnail
            if scan.hasPhoto, let photo = PassportDataStorage.loadPhoto(for: scan.id) {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 50)
                    .clipped()
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 50)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.fullName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(scan.nationality)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Doc: \(scan.documentNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if scan.isAuthenticated {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                }
                
                Text(DateFormatter.shortDate.string(from: scan.scanDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let sampleMRZ = MRZData(
        documentNumber: "L898902C3",
        dateOfBirth: "740812",
        expiryDate: "120415",
        rawMRZ: "L898902C3UTO7408122F1204159ZE184226B<<<<<10",
        documentType: "P",
        issuingCountry: "UTO",
        nationality: "UTO",
        sex: "F"
    )
    
    let samplePersonal = PersonalDetails(
        fullName: "ANNA MARIA ERIKSSON",
        surname: "ERIKSSON",
        givenNames: "ANNA MARIA",
        nationality: "UTO",
        dateOfBirth: "12/08/1974",
        placeOfBirth: "STOCKHOLM",
        sex: "F",
        documentNumber: "L898902C3",
        documentType: "P",
        issuingCountry: "UTO",
        expiryDate: "15/04/2012"
    )
    
    let sampleData = PassportData(
        mrzData: sampleMRZ,
        personalDetails: samplePersonal,
        photo: nil,
        additionalInfo: ["Issuing Authority": "Swedish Police"],
        chipAuthSuccess: true,
        bacSuccess: true,
        readingErrors: []
    )
    
    return ResultsView(passportData: sampleData, onScanAnother: {})
}
