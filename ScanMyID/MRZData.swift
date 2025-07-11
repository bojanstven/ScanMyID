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
        // Handle single line input (just the data line)
        let cleanLine = mrzText.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        // Document number is at positions 0-8 (9 characters)
        let startIndex = line2.startIndex
        let endIndex = line2.index(startIndex, offsetBy: 9)
        let docNumber = String(line2[startIndex..<endIndex])
        
        // Remove trailing '<' characters
        return docNumber.replacingOccurrences(of: "<", with: "")
    }
    
    private static func extractDateOfBirth(from line2: String) -> String {
        // Date of birth is at positions 13-18 (YYMMDD format)
        let startIndex = line2.index(line2.startIndex, offsetBy: 13)
        let endIndex = line2.index(startIndex, offsetBy: 6)
        return String(line2[startIndex..<endIndex])
    }
    
    private static func extractExpiryDate(from line2: String) -> String {
        // Expiry date is at positions 21-26 (YYMMDD format)
        let startIndex = line2.index(line2.startIndex, offsetBy: 21)
        let endIndex = line2.index(startIndex, offsetBy: 6)
        return String(line2[startIndex..<endIndex])
    }
}

// Extension to use in ResultsView
extension ResultsView {
    var parsedMRZ: MRZData? {
        return MRZParser.parse(mrzData)
    }
}
