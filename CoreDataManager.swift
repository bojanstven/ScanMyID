import Foundation
import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private var _persistentContainer: NSPersistentContainer?
    private var _context: NSManagedObjectContext?
    
    private init() {
        setupCoreData()
    }
    
    // MARK: - Core Data Stack (No Lazy Loading)
    
    private func setupCoreData() {
        let container = NSPersistentContainer(name: "ScanMyID")
        
        // Configure persistent store descriptions
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data error: \(error)")
                fatalError("Core Data failed to load: \(error)")
            } else {
                print("✅ Core Data loaded successfully")
            }
        }
        
        // Configure main context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Store references
        _persistentContainer = container
        _context = container.viewContext
        
        print("✅ Core Data setup complete - Context: \(_context!)")
        print("✅ Store Coordinator: \(_context!.persistentStoreCoordinator != nil)")
    }
    
    var persistentContainer: NSPersistentContainer {
        guard let container = _persistentContainer else {
            fatalError("Core Data not initialized")
        }
        return container
    }
    
    var context: NSManagedObjectContext {
        guard let context = _context else {
            fatalError("Core Data context not initialized")
        }
        
        // Additional safety check
        if context.persistentStoreCoordinator == nil {
            print("❌ Context lost its coordinator, reinitializing...")
            setupCoreData()
            return _context!
        }
        
        return context
    }
    
    private var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Context
    
    func save() {
        let context = self.context
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data saved successfully")
            } catch {
                print("❌ Core Data save error: \(error)")
            }
        }
    }
    
    // MARK: - Passport Operations
    
    @MainActor
    func savePassport(_ passportData: PassportData) async -> Bool {
        return await withCheckedContinuation { continuation in
            let backgroundContext = self.backgroundContext
            
            backgroundContext.perform {
                // Create SavedPassport entity
                let savedPassport = SavedPassport(context: backgroundContext)
                savedPassport.id = UUID()
                savedPassport.scanDate = Date()
                savedPassport.fullName = passportData.personalDetails?.fullName ?? "Unknown"
                savedPassport.nationality = passportData.personalDetails?.nationality ?? passportData.mrzData.nationality ?? "Unknown"
                savedPassport.documentNumber = passportData.personalDetails?.documentNumber ?? passportData.mrzData.documentNumber
                savedPassport.expiryDate = passportData.personalDetails?.expiryDate ?? passportData.mrzData.expiryDate
                savedPassport.isAuthenticated = passportData.isAuthenticated
                savedPassport.rawMRZ = passportData.mrzData.rawMRZ
                savedPassport.chipAuthSuccess = passportData.chipAuthSuccess
                savedPassport.bacSuccess = passportData.bacSuccess
                
                // Convert personal details to JSON
                if let personalDetails = passportData.personalDetails {
                    savedPassport.personalDetailsJSON = self.encodePersonalDetails(personalDetails)
                }
                
                // Convert additional info to JSON
                if !passportData.additionalInfo.isEmpty {
                    savedPassport.additionalInfoJSON = self.encodeAdditionalInfo(passportData.additionalInfo)
                }
                
                // Convert reading errors to JSON
                if !passportData.readingErrors.isEmpty {
                    savedPassport.readingErrorsJSON = self.encodeReadingErrors(passportData.readingErrors)
                }
                
                // Save photo if available
                if let photo = passportData.photo {
                    let passportPhoto = PassportPhoto(context: backgroundContext)
                    passportPhoto.id = UUID()
                    passportPhoto.imageData = photo.jpegData(compressionQuality: 0.8)
                    passportPhoto.passport = savedPassport
                }
                
                // Save context
                do {
                    try backgroundContext.save()
                    print("✅ Passport saved to Core Data")
                    
                    // Force main context refresh for immediate UI update
                    DispatchQueue.main.async {
                        self.context.refreshAllObjects()
                        // Also trigger any pending merges
                        try? self.context.save()
                    }
                    
                    // Clean up old scans (keep only last 50)
                    Task {
                        await self.cleanupOldScans()
                    }
                    
                    continuation.resume(returning: true)
                } catch {
                    print("❌ Failed to save passport: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    @MainActor
    func deletePassport(_ savedPassport: SavedPassport) async {
        let backgroundContext = self.backgroundContext
        
        await backgroundContext.perform {
            // Get the object in background context
            if let objectID = savedPassport.objectID.isTemporaryID ? nil : savedPassport.objectID,
               let passportInBG = try? backgroundContext.existingObject(with: objectID) as? SavedPassport {
                
                // Delete associated photo
                if let photo = passportInBG.photo {
                    backgroundContext.delete(photo)
                }
                
                // Delete passport
                backgroundContext.delete(passportInBG)
                
                // Save
                do {
                    try backgroundContext.save()
                    print("🗑️ Passport deleted from Core Data")
                    
                    // Refresh main context
                    DispatchQueue.main.async {
                        self.context.refreshAllObjects()
                    }
                } catch {
                    print("❌ Failed to delete passport: \(error)")
                }
            }
        }
    }
    
    @MainActor
    func loadPhoto(for passportId: UUID) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let backgroundContext = self.backgroundContext
            
            backgroundContext.perform {
                let request: NSFetchRequest<PassportPhoto> = PassportPhoto.fetchRequest()
                request.predicate = NSPredicate(format: "passport.id == %@", passportId as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let photos = try backgroundContext.fetch(request)
                    if let photoData = photos.first?.imageData,
                       let image = UIImage(data: photoData) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("❌ Failed to load photo: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func cleanupOldScans() async {
        await withCheckedContinuation { continuation in
            backgroundContext.perform {
                let request: NSFetchRequest<SavedPassport> = SavedPassport.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \SavedPassport.scanDate, ascending: false)]
                
                do {
                    let allPassports = try self.backgroundContext.fetch(request)
                    
                    // Keep only the 50 most recent
                    if allPassports.count > 50 {
                        let passportsToDelete = Array(allPassports.dropFirst(50))
                        
                        for passport in passportsToDelete {
                            if let photo = passport.photo {
                                self.backgroundContext.delete(photo)
                            }
                            self.backgroundContext.delete(passport)
                        }
                        
                        try self.backgroundContext.save()
                        print("🧹 Cleaned up \(passportsToDelete.count) old scans")
                        
                        // Refresh main context after cleanup
                        DispatchQueue.main.async {
                            self.context.refreshAllObjects()
                        }
                    }
                } catch {
                    print("❌ Failed to cleanup old scans: \(error)")
                }
                
                continuation.resume()
            }
        }
    }

    
    @MainActor
    func clearAllData() async {
        let backgroundContext = self.backgroundContext
        
        await backgroundContext.perform {
            // Delete all photos
            let photoRequest: NSFetchRequest<NSFetchRequestResult> = PassportPhoto.fetchRequest()
            let photoDeleteRequest = NSBatchDeleteRequest(fetchRequest: photoRequest)
            
            // Delete all passports
            let passportRequest: NSFetchRequest<NSFetchRequestResult> = SavedPassport.fetchRequest()
            let passportDeleteRequest = NSBatchDeleteRequest(fetchRequest: passportRequest)
            
            do {
                try backgroundContext.execute(photoDeleteRequest)
                try backgroundContext.execute(passportDeleteRequest)
                try backgroundContext.save()
                print("🧹 All Core Data cleared")
                
                // Refresh main context after clearing all data
                DispatchQueue.main.async {
                    self.context.refreshAllObjects()
                }
            } catch {
                print("❌ Failed to clear Core Data: \(error)")
            }
        }
    }
    
    // MARK: - JSON Encoding Helpers
    
    private func encodePersonalDetails(_ personalDetails: PersonalDetails) -> String {
        let dict: [String: String] = [
            "fullName": personalDetails.fullName,
            "surname": personalDetails.surname,
            "givenNames": personalDetails.givenNames,
            "nationality": personalDetails.nationality,
            "dateOfBirth": personalDetails.dateOfBirth,
            "placeOfBirth": personalDetails.placeOfBirth ?? "",
            "sex": personalDetails.sex,
            "documentNumber": personalDetails.documentNumber,
            "documentType": personalDetails.documentType,
            "issuingCountry": personalDetails.issuingCountry,
            "expiryDate": personalDetails.expiryDate
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private func encodeAdditionalInfo(_ additionalInfo: [String: String]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: additionalInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private func encodeReadingErrors(_ errors: [String]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: errors),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "[]"
    }
    
    // MARK: - JSON Decoding Helpers
    
    func decodePersonalDetails(from jsonString: String?) -> PersonalDetails? {
        guard let jsonString = jsonString,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            return nil
        }
        
        return PersonalDetails(
            fullName: dict["fullName"] ?? "",
            surname: dict["surname"] ?? "",
            givenNames: dict["givenNames"] ?? "",
            nationality: dict["nationality"] ?? "",
            dateOfBirth: dict["dateOfBirth"] ?? "",
            placeOfBirth: dict["placeOfBirth"]?.isEmpty == true ? nil : dict["placeOfBirth"],
            sex: dict["sex"] ?? "",
            documentNumber: dict["documentNumber"] ?? "",
            documentType: dict["documentType"] ?? "",
            issuingCountry: dict["issuingCountry"] ?? "",
            expiryDate: dict["expiryDate"] ?? ""
        )
    }
    
    func decodeAdditionalInfo(from jsonString: String?) -> [String: String] {
        guard let jsonString = jsonString,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            return [:]
        }
        return dict
    }
    
    func decodeReadingErrors(from jsonString: String?) -> [String] {
        guard let jsonString = jsonString,
              let jsonData = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            return []
        }
        return array
    }
}

// MARK: - SavedPassport Extensions

extension SavedPassport {
    var completePassportData: PassportData? {
        // Parse MRZ data
        guard let rawMRZ = self.rawMRZ,
              let parsedMRZ = MRZParser.parse(rawMRZ) else {
            // Fallback MRZ data
            let fallbackMRZ = MRZData(
                documentNumber: self.documentNumber ?? "",
                dateOfBirth: "000000",
                expiryDate: self.expiryDate ?? "",
                rawMRZ: self.rawMRZ ?? "",
                documentType: "P",
                issuingCountry: self.nationality,
                nationality: self.nationality,
                sex: "M"
            )
            return createPassportData(with: fallbackMRZ)
        }
        
        return createPassportData(with: parsedMRZ)
    }
    
    private func createPassportData(with mrzData: MRZData) -> PassportData {
        // Decode personal details
        let personalDetails = CoreDataManager.shared.decodePersonalDetails(from: self.personalDetailsJSON)
        
        // Decode additional info
        let additionalInfo = CoreDataManager.shared.decodeAdditionalInfo(from: self.additionalInfoJSON)
        
        // Decode reading errors
        let readingErrors = CoreDataManager.shared.decodeReadingErrors(from: self.readingErrorsJSON)
        
        // Get photo (this will be loaded on-demand)
        var photo: UIImage?
        if let photoData = self.photo?.imageData {
            photo = UIImage(data: photoData)
        }
        
        return PassportData(
            mrzData: mrzData,
            personalDetails: personalDetails,
            photo: photo,
            additionalInfo: additionalInfo,
            chipAuthSuccess: self.chipAuthSuccess,
            bacSuccess: self.bacSuccess,
            readingErrors: readingErrors
        )
    }
}
