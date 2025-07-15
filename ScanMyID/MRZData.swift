//

import Foundation

struct MRZData {
    let documentNumber: String
    let dateOfBirth: String
    let expiryDate: String
    let rawMRZ: String
    
    // NFC BAC key generation
    var bacKey: String {
        return documentNumber + dateOfBirth + expiryDate
    }
}

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
        
        guard !documentNumber.isEmpty && !dateOfBirth.isEmpty && !expiryDate.isEmpty else {
            return nil
        }
        
        let mrzData = MRZData(
            documentNumber: documentNumber,
            dateOfBirth: dateOfBirth,
            expiryDate: expiryDate,
            rawMRZ: cleanLine
        )
        
        // Clean logging - no error messages
        print("📄 Document: \(documentNumber)")
        print("🎂 DOB: \(dateOfBirth)")
        print("📅 Expiry: \(expiryDate)")
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
}

// Extension to use in ResultsView
extension ResultsView {
    var parsedMRZ: MRZData? {
        return MRZParser.parse(mrzData)
    }
}
