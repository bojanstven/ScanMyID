//

import Foundation
import UIKit

// MARK: - Enhanced MRZData with more fields

struct MRZData {
    let documentNumber: String
    let dateOfBirth: String
    let expiryDate: String
    let rawMRZ: String
    
    // Additional parsed fields
    let documentType: String?
    let issuingCountry: String?
    let nationality: String?
    let sex: String?
    
    // NFC BAC key generation
    var bacKey: String {
        return documentNumber + dateOfBirth + expiryDate
    }
}

// MARK: - Enhanced PersonalDetails with complete information

struct PersonalDetails {
    let fullName: String
    let surname: String
    let givenNames: String
    let nationality: String
    let dateOfBirth: String
    let placeOfBirth: String?
    let sex: String
    let documentNumber: String
    let documentType: String
    let issuingCountry: String
    let expiryDate: String
}

// MARK: - Enhanced PassportData with comprehensive information

struct PassportData {
    let mrzData: MRZData
    let personalDetails: PersonalDetails?
    let photo: UIImage?
    let additionalInfo: [String: String]
    let chipAuthSuccess: Bool
    let bacSuccess: Bool
    let readingErrors: [String]
    
    // Computed properties for easy access
    var hasPhoto: Bool { photo != nil }
    var isAuthenticated: Bool { chipAuthSuccess && bacSuccess }
    var readingDate: Date { Date() }
}

// MARK: - Enhanced MRZParser with more comprehensive parsing

class MRZParser {
    
    static func parse(_ mrzText: String) -> MRZData? {
        // First, validate and correct common OCR errors
        let correctedMRZ = validateAndCorrectMRZ(mrzText)
        
        // Handle single line input (just the data line)
        let cleanLine = correctedMRZ.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a single line (44 chars) or multiple lines
        if cleanLine.contains("\n") {
            // Multiple lines - use second line
            let lines = cleanLine.components(separatedBy: "\n")
            guard lines.count >= 2 else { return nil }
            return parseSingleLine(lines[1])
        } else {
            // Single line - parse directly
            return parseSingleLine(cleanLine)
        }
    }
    
    // Validate and correct common OCR errors in MRZ
    private static func validateAndCorrectMRZ(_ mrz: String) -> String {
        var corrected = mrz.uppercased().replacingOccurrences(of: " ", with: "")
        print("🔧 Original MRZ: \(mrz)")
        
        // Check basic length (should be 44 chars for passport MRZ line 2)
        guard corrected.count >= 44 else {
            print("❌ MRZ too short: \(corrected.count) chars")
            return corrected
        }
        
        // Extract gender field (position 20)
        let genderIndex = corrected.index(corrected.startIndex, offsetBy: 20)
        let gender = String(corrected[genderIndex])
        
        print("🔍 Original gender field: '\(gender)'")
        
        // Fix common OCR errors in gender field
        let correctedGender: String
        var wasFixed = false
        
        if gender == "9" || gender == "0" || gender == "Q" || gender == "H" || gender == "8" {
            correctedGender = "M"
            wasFixed = true
            print("🔧 Fixed gender: '\(gender)' → 'M'")
        } else if gender == "1" || gender == "I" || gender == "l" {
            correctedGender = "F"
            wasFixed = true
            print("🔧 Fixed gender: '\(gender)' → 'F'")
        } else if gender != "M" && gender != "F" {
            correctedGender = "M" // Default to M for unrecognized characters
            wasFixed = true
            print("🔧 Fixed gender: '\(gender)' → 'M' (default)")
        } else {
            correctedGender = gender
            print("✅ Gender field correct: '\(gender)'")
        }
        
        // Apply correction if needed
        if wasFixed {
            var characters = Array(corrected)
            characters[20] = Character(correctedGender)
            corrected = String(characters)
            print("🔧 Corrected MRZ: \(corrected)")
        }
        
        return corrected
    }
    
    private static func parseSingleLine(_ line: String) -> MRZData? {
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate line length (should be 44 characters)
        guard cleanLine.count == 44 else {
            return nil
        }
        
        let documentNumber = extractDocumentNumber(from: cleanLine)
        let dateOfBirth = extractDateOfBirth(from: cleanLine)
        let expiryDate = extractExpiryDate(from: cleanLine)
        let nationality = extractNationality(from: cleanLine)
        let sex = extractSex(from: cleanLine)
        
        guard !documentNumber.isEmpty && !dateOfBirth.isEmpty && !expiryDate.isEmpty else {
            return nil
        }
        
        let mrzData = MRZData(
            documentNumber: documentNumber,
            dateOfBirth: dateOfBirth,
            expiryDate: expiryDate,
            rawMRZ: cleanLine,
            documentType: "P", // Assume passport for now
            issuingCountry: extractIssuingCountry(from: cleanLine),
            nationality: nationality,
            sex: sex
        )
        
        // Clean logging - no error messages
        print("📄 Document: \(documentNumber)")
        print("🎂 DOB: \(dateOfBirth)")
        print("📅 Expiry: \(expiryDate)")
        print("🏳️ Nationality: \(nationality ?? "Unknown")")
        print("👤 Sex: \(sex ?? "Unknown")")
        print("🔑 BAC Key: \(mrzData.bacKey)")
        
        return mrzData
    }
    
    private static func extractDocumentNumber(from line2: String) -> String {
        // Document number WITH check digit is at positions 0-9 (10 characters total)
        let startIndex = line2.startIndex
        let endIndex = line2.index(startIndex, offsetBy: 10)
        let docNumberWithCheck = String(line2[startIndex..<endIndex])
        
        // Remove trailing '<' characters but KEEP the check digit
        return docNumberWithCheck.replacingOccurrences(of: "<", with: "")
    }
    
    private static func extractDateOfBirth(from line2: String) -> String {
        // Date of birth WITH check digit is at positions 13-19 (7 characters total)
        let startIndex = line2.index(line2.startIndex, offsetBy: 13)
        let endIndex = line2.index(startIndex, offsetBy: 7)
        return String(line2[startIndex..<endIndex])
    }
    
    private static func extractExpiryDate(from line2: String) -> String {
        // Expiry date WITH check digit is at positions 21-27 (7 characters total)
        let startIndex = line2.index(line2.startIndex, offsetBy: 21)
        let endIndex = line2.index(startIndex, offsetBy: 7)
        return String(line2[startIndex..<endIndex])
    }
    
    private static func extractNationality(from line2: String) -> String? {
        // Nationality is at positions 10-12 (3 characters)
        guard line2.count >= 13 else { return nil }
        let startIndex = line2.index(line2.startIndex, offsetBy: 10)
        let endIndex = line2.index(startIndex, offsetBy: 3)
        return String(line2[startIndex..<endIndex]).replacingOccurrences(of: "<", with: "")
    }
    
    private static func extractSex(from line2: String) -> String? {
        // Sex is at position 20 (1 character)
        guard line2.count >= 21 else { return nil }
        let index = line2.index(line2.startIndex, offsetBy: 20)
        return String(line2[index])
    }
    
    private static func extractIssuingCountry(from line2: String) -> String? {
        // For now, assume it's the same as nationality (this might need refinement)
        return extractNationality(from: line2)
    }
}

// MARK: - Data Persistence Models

struct SavedPassportScan: Codable {
    let id: UUID
    let scanDate: Date
    let documentNumber: String
    let fullName: String
    let nationality: String
    let expiryDate: String
    let hasPhoto: Bool
    let isAuthenticated: Bool
    
    init(from passportData: PassportData) {
        self.id = UUID()
        self.scanDate = Date()
        self.documentNumber = passportData.personalDetails?.documentNumber ?? passportData.mrzData.documentNumber
        self.fullName = passportData.personalDetails?.fullName ?? "Unknown"
        self.nationality = passportData.personalDetails?.nationality ?? passportData.mrzData.nationality ?? "Unknown"
        self.expiryDate = passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
        self.hasPhoto = passportData.hasPhoto
        self.isAuthenticated = passportData.isAuthenticated
    }
}

// MARK: - Local Storage Helper

class PassportDataStorage {
    private static let scansKey = "SavedPassportScans"
    private static let photosDirectory = "PassportPhotos"
    
    static func savePassportData(_ passportData: PassportData) -> Bool {
        // Save metadata
        let savedScan = SavedPassportScan(from: passportData)
        var existingScans = loadSavedScans()
        existingScans.append(savedScan)
        
        // Limit to last 50 scans
        if existingScans.count > 50 {
            existingScans = Array(existingScans.suffix(50))
        }
        
        do {
            let data = try JSONEncoder().encode(existingScans)
            UserDefaults.standard.set(data, forKey: scansKey)
            
            // Save photo separately if available
            if let photo = passportData.photo {
                savePhoto(photo, for: savedScan.id)
            }
            
            print("💾 Passport data saved successfully")
            return true
        } catch {
            print("❌ Failed to save passport data: \(error)")
            return false
        }
    }
    
    static func loadSavedScans() -> [SavedPassportScan] {
        guard let data = UserDefaults.standard.data(forKey: scansKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([SavedPassportScan].self, from: data)
        } catch {
            print("❌ Failed to load saved scans: \(error)")
            return []
        }
    }
    
    private static func savePhoto(_ photo: UIImage, for id: UUID) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let photosDirectory = documentsDirectory.appendingPathComponent(Self.photosDirectory)
        
        // Create photos directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        let photoURL = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        if let jpegData = photo.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: photoURL)
        }
    }
    
    static func loadPhoto(for id: UUID) -> UIImage? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let photosDirectory = documentsDirectory.appendingPathComponent(Self.photosDirectory)
        let photoURL = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        guard let data = try? Data(contentsOf: photoURL) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    static func deleteScan(_ scan: SavedPassportScan) {
        var existingScans = loadSavedScans()
        existingScans.removeAll { $0.id == scan.id }
        
        do {
            let data = try JSONEncoder().encode(existingScans)
            UserDefaults.standard.set(data, forKey: scansKey)
            
            // Delete associated photo
            deletePhoto(for: scan.id)
            
            print("🗑️ Scan deleted successfully")
        } catch {
            print("❌ Failed to delete scan: \(error)")
        }
    }
    
    private static func deletePhoto(for id: UUID) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let photosDirectory = documentsDirectory.appendingPathComponent(Self.photosDirectory)
        let photoURL = photosDirectory.appendingPathComponent("\(id.uuidString).jpg")
        
        try? FileManager.default.removeItem(at: photoURL)
    }
    
    static func clearAllData() {
        UserDefaults.standard.removeObject(forKey: scansKey)
        
        // Delete all photos
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let photosDirectory = documentsDirectory.appendingPathComponent(Self.photosDirectory)
        try? FileManager.default.removeItem(at: photosDirectory)
        
        print("🧹 All passport data cleared")
    }
}

// Extensions for compatibility
extension PersonalDetails {
    // Make placeOfBirth mutable for updates
    func withPlaceOfBirth(_ placeOfBirth: String?) -> PersonalDetails {
        return PersonalDetails(
            fullName: self.fullName,
            surname: self.surname,
            givenNames: self.givenNames,
            nationality: self.nationality,
            dateOfBirth: self.dateOfBirth,
            placeOfBirth: placeOfBirth,
            sex: self.sex,
            documentNumber: self.documentNumber,
            documentType: self.documentType,
            issuingCountry: self.issuingCountry,
            expiryDate: self.expiryDate
        )
    }
}
