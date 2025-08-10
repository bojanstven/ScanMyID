import Foundation
import UIKit
import SwiftUI

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

// MARK: - Enhanced Passport Expiry Validation with Crypto Authentication

enum PassportValidityStatus {
    case valid          // ✅ More than 3 months remaining
    case expiresSoon     // ⚠️ Less than 3 months remaining
    case expired        // ❌ Past expiry date
    
    var icon: String {
        switch self {
        case .valid: return "✅"
        case .expiresSoon: return "⚠️"
        case .expired: return "❌"
        }
    }
    
    var color: Color {
        switch self {
        case .valid: return .green
        case .expiresSoon: return .orange
        case .expired: return .red
        }
    }
    
    var description: String {
        switch self {
        case .valid: return "Valid"
        case .expiresSoon: return "Expires Soon"
        case .expired: return "Expired"
        }
    }
}

// MARK: - Crypto Authentication Status for Overlay

enum CryptoAuthStatus {
    case verified       // ✅ DG1 hash validated successfully
    case unverified     // ⚠️ Cannot validate DG1 hash (rare)
    case compromised    // ❌ Major crypto failure/tampering detected
    
    var icon: String {
        switch self {
        case .verified: return "checkmark.shield.fill"
        case .unverified: return "questionmark.shield.fill"
        case .compromised: return "xmark.shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .verified: return .green
        case .unverified: return .yellow
        case .compromised: return .red
        }
    }
    
    var description: String {
        switch self {
        case .verified: return "Verified"
        case .unverified: return "Unverified"
        case .compromised: return "Compromised"
        }
    }
}

// MARK: - Enhanced Time Formatting Functions

struct ExpiryFormatter {
    
    /// Enhanced human-readable time formatting with full words
    /// Examples: "2 years 3 months", "45 days", "Expired (-1 year 2 months)", "Expired (-234 days)"
    static func formatTimeRemaining(from expiryDate: Date) -> String {
        let today = Date()
        let calendar = Calendar.current
        
        if expiryDate >= today {
            // Future date - time remaining
            let components = calendar.dateComponents([.year, .month, .day], from: today, to: expiryDate)
            
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            // For periods over 2 years, show years and months
            if years >= 2 {
                let yearText = years == 1 ? "year" : "years"
                let monthText = months == 1 ? "month" : "months"
                return "\(years) \(yearText) \(months) \(monthText)"
            }
            // For periods over 6 months, show months and days
            else if years >= 1 || months >= 6 {
                let totalMonths = years * 12 + months
                let monthText = totalMonths == 1 ? "month" : "months"
                let dayText = days == 1 ? "day" : "days"
                return "\(totalMonths) \(monthText) \(days) \(dayText)"
            }
            // For shorter periods, show total days
            else {
                let totalDays = calendar.dateComponents([.day], from: today, to: expiryDate).day ?? 0
                let dayText = totalDays == 1 ? "day" : "days"
                return "\(totalDays) \(dayText)"
            }
        } else {
            // Past date - expired
            let components = calendar.dateComponents([.year, .month, .day], from: expiryDate, to: today)
            
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            // For expired periods over 2 years
            if years >= 2 {
                let yearText = years == 1 ? "year" : "years"
                let monthText = months == 1 ? "month" : "months"
                return "Expired (-\(years) \(yearText) \(months) \(monthText))"
            }
            // For expired periods over 6 months
            else if years >= 1 || months >= 6 {
                let totalMonths = years * 12 + months
                let monthText = totalMonths == 1 ? "month" : "months"
                return "Expired (-\(totalMonths) \(monthText))"
            }
            // For recently expired (less than 6 months)
            else {
                let totalDays = calendar.dateComponents([.day], from: expiryDate, to: today).day ?? 0
                let dayText = totalDays == 1 ? "day" : "days"
                return "Expired (-\(totalDays) \(dayText))"
            }
        }
    }
    
    /// Compact format for UI constraints with abbreviations for rows
    /// Examples: "2y 3m", "45 days", "-1y 2m", "-234 days"
    static func formatTimeRemainingCompact(from expiryDate: Date) -> String {
        let today = Date()
        let calendar = Calendar.current
        
        if expiryDate >= today {
            let components = calendar.dateComponents([.year, .month, .day], from: today, to: expiryDate)
            
            let years = components.year ?? 0
            let months = components.month ?? 0
            
            if years >= 1 {
                return "\(years)y \(months)m"
            } else if months >= 3 {
                let monthText = months == 1 ? "month" : "months"
                return "\(months) \(monthText)"
            } else {
                let totalDays = calendar.dateComponents([.day], from: today, to: expiryDate).day ?? 0
                let dayText = totalDays == 1 ? "day" : "days"
                return "\(totalDays) \(dayText)"
            }
        } else {
            let components = calendar.dateComponents([.year, .month, .day], from: expiryDate, to: today)
            
            let years = components.year ?? 0
            let months = components.month ?? 0
            
            if years >= 1 {
                return "-\(years)y \(months)m"
            } else if months >= 3 {
                let monthText = months == 1 ? "month" : "months"
                return "-\(months) \(monthText)"
            } else {
                let totalDays = calendar.dateComponents([.day], from: expiryDate, to: today).day ?? 0
                let dayText = totalDays == 1 ? "day" : "days"
                return "-\(totalDays) \(dayText)"
            }
        }
    }
}

func checkPassportValidity(expiryDate: Date) -> PassportValidityStatus {
    let today = Date()
    if expiryDate < today {
        return .expired
    }
    
    let daysLeft = Calendar.current.dateComponents([.day], from: today, to: expiryDate).day ?? 0
    if daysLeft < 90 { // Less than 3 months
        return .expiresSoon
    }
    
    return .valid
}

/// Determine crypto authentication status based on passport data
func determineCryptoAuthStatus(passportData: PassportData) -> CryptoAuthStatus {
    // Current logic: Green if DG1 hash is verified (chipAuthSuccess)
    // Yellow if BAC worked but chip auth failed (rare case)
    // Red if major failure (for future digital signature validation)
    
    if passportData.chipAuthSuccess {
        return .verified
    } else if passportData.bacSuccess {
        // BAC worked but chip authentication failed - rare but possible
        return .unverified
    } else {
        // Complete failure - could indicate tampering or fake document
        // TODO: When digital signature verification is implemented,
        // this should also check:
        // - SOD certificate chain validation against master list
        // - Country certificate validation against CSCA master list
        // - Digital signature verification of document security object
        // - Anti-cloning measures and active authentication
        return .compromised
    }
}

// Helper to parse date from MRZ format (YYMMDD)
func parseExpiryDate(_ dateString: String) -> Date? {
    // Handle different date formats
    let formatters = [
        DateFormatter.yyMMdd,
        DateFormatter.ddMMyyyy,
        DateFormatter.shortDate
    ]
    
    for formatter in formatters {
        if let date = formatter.date(from: dateString) {
            return date
        }
    }
    
    return nil
}

// MARK: - Comprehensive Country Flags Helper (ICAO Biometric Passport Countries)

struct CountryFlags {
    static func flag(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        
        // Full List of Countries with Biometric Passports (ePassports) — ISO 3166 Alpha-3 Code + Flag
        // Alphabetically ordered and comprehensive
        let flagMap: [String: String] = [
            "AFG": "🇦🇫", // Afghanistan
            "ALB": "🇦🇱", // Albania
            "DZA": "🇩🇿", // Algeria
            "AND": "🇦🇩", // Andorra
            "AGO": "🇦🇴", // Angola
            "ARG": "🇦🇷", // Argentina
            "ARM": "🇦🇲", // Armenia
            "AUS": "🇦🇺", // Australia
            "AUT": "🇦🇹", // Austria
            "AZE": "🇦🇿", // Azerbaijan
            "BGD": "🇧🇩", // Bangladesh
            "BLR": "🇧🇾", // Belarus
            "BEL": "🇧🇪", // Belgium
            "BEN": "🇧🇯", // Benin
            "BIH": "🇧🇦", // Bosnia and Herzegovina
            "BOL": "🇧🇴", // Bolivia
            "BRA": "🇧🇷", // Brazil
            "BGR": "🇧🇬", // Bulgaria
            "BFA": "🇧🇫", // Burkina Faso
            "BDI": "🇧🇮", // Burundi
            "KHM": "🇰🇭", // Cambodia
            "CMR": "🇨🇲", // Cameroon
            "CAN": "🇨🇦", // Canada
            "CPV": "🇨🇻", // Cape Verde
            "CAF": "🇨🇫", // Central African Republic
            "TCD": "🇹🇩", // Chad
            "CHL": "🇨🇱", // Chile
            "CHN": "🇨🇳", // China
            "COL": "🇨🇴", // Colombia
            "COM": "🇰🇲", // Comoros
            "COG": "🇨🇬", // Congo
            "CRI": "🇨🇷", // Costa Rica
            "CIV": "🇨🇮", // Côte d'Ivoire
            "HRV": "🇭🇷", // Croatia
            "CYP": "🇨🇾", // Cyprus
            "CZE": "🇨🇿", // Czech Republic
            "COD": "🇨🇩", // Democratic Republic of the Congo
            "DNK": "🇩🇰", // Denmark
            "DJI": "🇩🇯", // Djibouti
            "DOM": "🇩🇴", // Dominican Republic
            "ECU": "🇪🇨", // Ecuador
            "EGY": "🇪🇬", // Egypt
            "SLV": "🇸🇻", // El Salvador
            "GNQ": "🇬🇶", // Equatorial Guinea
            "EST": "🇪🇪", // Estonia
            "ETH": "🇪🇹", // Ethiopia
            "FJI": "🇫🇯", // Fiji
            "FIN": "🇫🇮", // Finland
            "FRA": "🇫🇷", // France
            "GAB": "🇬🇦", // Gabon
            "GMB": "🇬🇲", // Gambia
            "GEO": "🇬🇪", // Georgia
            "DEU": "🇩🇪", // Germany
            "GHA": "🇬🇭", // Ghana
            "GRC": "🇬🇷", // Greece
            "GRD": "🇬🇩", // Grenada
            "GTM": "🇬🇹", // Guatemala
            "GIN": "🇬🇳", // Guinea
            "GUY": "🇬🇾", // Guyana
            "HTI": "🇭🇹", // Haiti
            "HND": "🇭🇳", // Honduras
            "HUN": "🇭🇺", // Hungary
            "ISL": "🇮🇸", // Iceland
            "IND": "🇮🇳", // India
            "IDN": "🇮🇩", // Indonesia
            "IRN": "🇮🇷", // Iran
            "IRQ": "🇮🇶", // Iraq
            "IRL": "🇮🇪", // Ireland
            "ISR": "🇮🇱", // Israel
            "ITA": "🇮🇹", // Italy
            "JAM": "🇯🇲", // Jamaica
            "JPN": "🇯🇵", // Japan
            "JOR": "🇯🇴", // Jordan
            "KAZ": "🇰🇿", // Kazakhstan
            "KEN": "🇰🇪", // Kenya
            "KWT": "🇰🇼", // Kuwait
            "KGZ": "🇰🇬", // Kyrgyzstan
            "LAO": "🇱🇦", // Laos
            "LVA": "🇱🇻", // Latvia
            "LBN": "🇱🇧", // Lebanon
            "LSO": "🇱🇸", // Lesotho
            "LBR": "🇱🇷", // Liberia
            "LBY": "🇱🇾", // Libya
            "LIE": "🇱🇮", // Liechtenstein
            "LTU": "🇱🇹", // Lithuania
            "LUX": "🇱🇺", // Luxembourg
            "MDG": "🇲🇬", // Madagascar
            "MWI": "🇲🇼", // Malawi
            "MYS": "🇲🇾", // Malaysia
            "MDV": "🇲🇻", // Maldives
            "MLI": "🇲🇱", // Mali
            "MLT": "🇲🇹", // Malta
            "MRT": "🇲🇷", // Mauritania
            "MUS": "🇲🇺", // Mauritius
            "MEX": "🇲🇽", // Mexico
            "MDA": "🇲🇩", // Moldova
            "MNG": "🇲🇳", // Mongolia
            "MNE": "🇲🇪", // Montenegro
            "MAR": "🇲🇦", // Morocco
            "MOZ": "🇲🇿", // Mozambique
            "MMR": "🇲🇲", // Myanmar
            "NAM": "🇳🇦", // Namibia
            "NPL": "🇳🇵", // Nepal
            "NLD": "🇳🇱", // Netherlands
            "NZL": "🇳🇿", // New Zealand
            "NER": "🇳🇪", // Niger
            "NGA": "🇳🇬", // Nigeria
            "MKD": "🇲🇰", // North Macedonia
            "NOR": "🇳🇴", // Norway
            "OMN": "🇴🇲", // Oman
            "PAK": "🇵🇰", // Pakistan
            "PAN": "🇵🇦", // Panama
            "PNG": "🇵🇬", // Papua New Guinea
            "PRY": "🇵🇾", // Paraguay
            "PER": "🇵🇪", // Peru
            "PHL": "🇵🇭", // Philippines
            "POL": "🇵🇱", // Poland
            "PRT": "🇵🇹", // Portugal
            "QAT": "🇶🇦", // Qatar
            "ROU": "🇷🇴", // Romania
            "RUS": "🇷🇺", // Russia
            "RWA": "🇷🇼", // Rwanda
            "SAU": "🇸🇦", // Saudi Arabia
            "SEN": "🇸🇳", // Senegal
            "SRB": "🇷🇸", // Serbia
            "SGP": "🇸🇬", // Singapore
            "SVK": "🇸🇰", // Slovakia
            "SVN": "🇸🇮", // Slovenia
            "ZAF": "🇿🇦", // South Africa
            "ESP": "🇪🇸", // Spain
            "LKA": "🇱🇰", // Sri Lanka
            "SDN": "🇸🇩", // Sudan
            "SUR": "🇸🇷", // Suriname
            "SWZ": "🇸🇿", // Swaziland (Eswatini)
            "SWE": "🇸🇪", // Sweden
            "CHE": "🇨🇭", // Switzerland
            "SYR": "🇸🇾", // Syria
            "TWN": "🇹🇼", // Taiwan
            "TJK": "🇹🇯", // Tajikistan
            "THA": "🇹🇭", // Thailand
            "TGO": "🇹🇬", // Togo
            "TUN": "🇹🇳", // Tunisia
            "TUR": "🇹🇷", // Turkey
            "TKM": "🇹🇲", // Turkmenistan
            "UGA": "🇺🇬", // Uganda
            "UKR": "🇺🇦", // Ukraine
            "ARE": "🇦🇪", // United Arab Emirates
            "GBR": "🇬🇧", // United Kingdom
            "USA": "🇺🇸", // United States
            "URY": "🇺🇾", // Uruguay
            "UZB": "🇺🇿", // Uzbekistan
            "VEN": "🇻🇪", // Venezuela
            "VNM": "🇻🇳", // Vietnam
            "YEM": "🇾🇪", // Yemen
            "ZMB": "🇿🇲", // Zambia
            "ZWE": "🇿🇼"  // Zimbabwe
        ]
        
        return flagMap[code] ?? "🏳️"
    }
    
    static func flagWithCode(_ countryCode: String) -> String {
        let flag = flag(for: countryCode)
        return "\(flag) \(countryCode)"
    }
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

// MARK: - Extensions for compatibility

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
    
    static let yyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        return formatter
    }()
    
    static let ddMMyyyy: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}
