import Foundation
import CoreData
import UIKit

/// Enhanced Core Data Manager for ScanMyID v1.5.0
/// Manages passport data storage with improved performance and v1.5 compatibility
class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {
        print("🗃️ CoreDataManager initialized for ScanMyID v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ScanMyID")
        
        // Enhanced configuration for better performance
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = true
        description?.shouldMigrateStoreAutomatically = true
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("❌ Core Data error: \(error)")
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data store loaded successfully")
            }
        }
        
        // Enhanced merge policy for better conflict resolution
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Enhanced Save Function with Better Error Handling
    
    private func saveContext() async -> Bool {
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else {
            print("📝 No changes to save")
            return true
        }
        
        do {
            try context.save()
            print("✅ Context saved successfully")
            return true
        } catch {
            print("❌ Save error: \(error)")
            
            // Enhanced error recovery
            if let nsError = error as NSError? {
                print("❌ Core Data save error details:")
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
                
                // Attempt to rollback and retry
                context.rollback()
                print("🔄 Context rolled back, attempting retry...")
                
                // Try saving again after rollback
                do {
                    try context.save()
                    print("✅ Retry save successful")
                    return true
                } catch {
                    print("❌ Retry save failed: \(error)")
                    return false
                }
            }
            
            return false
        }
    }
    
    // MARK: - Enhanced Passport Saving with v1.5 Compatibility
    
    func savePassport(_ passportData: PassportData) async -> Bool {
        print("💾 Saving passport data for v1.5.0...")
        
        let context = persistentContainer.viewContext
        
        return await withCheckedContinuation { continuation in
            context.perform {
                Task {
                    do {
                        // Create new SavedPassport entity
                        let savedPassport = SavedPassport(context: context)
                        savedPassport.id = UUID()
                        savedPassport.scanDate = Date()
                        
                        // Enhanced personal details handling
                        if let personalDetails = passportData.personalDetails {
                            savedPassport.fullName = personalDetails.fullName
                            savedPassport.nationality = personalDetails.nationality
                            savedPassport.documentNumber = personalDetails.documentNumber
                            savedPassport.expiryDate = personalDetails.expiryDate // Important for v1.5 expiry focus
                            
                            // Store complete personal details as JSON for full reconstruction
                            let personalDetailsData = try JSONEncoder().encode([
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
                            ])
                            savedPassport.personalDetailsJSON = String(data: personalDetailsData, encoding: .utf8)
                        } else {
                            // Fallback to MRZ data for essential fields
                            savedPassport.fullName = "Unknown"
                            savedPassport.nationality = passportData.mrzData.nationality
                            savedPassport.documentNumber = passportData.mrzData.documentNumber
                            savedPassport.expiryDate = passportData.mrzData.expiryDate // Critical for v1.5
                        }
                        
                        // Enhanced authentication status storage (important for v1.5 crypto overlay)
                        savedPassport.bacSuccess = passportData.bacSuccess
                        savedPassport.chipAuthSuccess = passportData.chipAuthSuccess
                        savedPassport.isAuthenticated = passportData.isAuthenticated
                        
                        // Store additional info as JSON
                        if !passportData.additionalInfo.isEmpty {
                            let additionalInfoData = try JSONEncoder().encode(passportData.additionalInfo)
                            savedPassport.additionalInfoJSON = String(data: additionalInfoData, encoding: .utf8)
                        }
                        
                        // Store reading errors
                        if !passportData.readingErrors.isEmpty {
                            let errorsData = try JSONEncoder().encode(passportData.readingErrors)
                            savedPassport.readingErrorsJSON = String(data: errorsData, encoding: .utf8)
                        }
                        
                        // Store MRZ data
                        savedPassport.rawMRZ = passportData.mrzData.rawMRZ
                        
                        // Enhanced photo handling
                        if let photo = passportData.photo {
                            let passportPhoto = PassportPhoto(context: context)
                            passportPhoto.id = UUID()
                            
                            // Optimize image storage
                            if let imageData = photo.jpegData(compressionQuality: 0.8) {
                                passportPhoto.imageData = imageData
                                savedPassport.photo = passportPhoto
                                print("📸 Photo saved (\(imageData.count) bytes)")
                            } else {
                                print("⚠️ Failed to convert photo to JPEG data")
                            }
                        }
                        
                        // Save to Core Data
                        let success = await self.saveContext()
                        
                        if success {
                            print("✅ Passport saved successfully with v1.5 compatibility")
                            print("   Full Name: \(savedPassport.fullName ?? "Unknown")")
                            print("   Document: \(savedPassport.documentNumber ?? "Unknown")")
                            print("   Expiry: \(savedPassport.expiryDate ?? "Unknown")")
                            print("   BAC Success: \(savedPassport.bacSuccess)")
                            print("   Chip Auth: \(savedPassport.chipAuthSuccess)")
                            print("   Has Photo: \(savedPassport.photo != nil)")
                        }
                        
                        continuation.resume(returning: success)
                        
                    } catch {
                        print("❌ Error saving passport: \(error)")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Photo Loading with Optimization
    
    func loadPhoto(for passportId: UUID) async -> UIImage? {
        let context = persistentContainer.viewContext
        
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<SavedPassport> = SavedPassport.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", passportId as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let passports = try context.fetch(request)
                    if let passport = passports.first,
                       let photo = passport.photo,
                       let imageData = photo.imageData,
                       let image = UIImage(data: imageData) {
                        print("📸 Photo loaded for passport \(passportId)")
                        continuation.resume(returning: image)
                    } else {
                        print("📸 No photo found for passport \(passportId)")
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("❌ Error loading photo: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Enhanced Deletion with Cascade Handling
    
    func deletePassport(_ passport: SavedPassport) async {
        let context = persistentContainer.viewContext
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            context.perform {
                Task {
                    print("🗑️ Deleting passport: \(passport.fullName ?? "Unknown")")
                    
                    // Core Data will handle cascading delete of photo automatically
                    context.delete(passport)
                    
                    let success = await self.saveContext()
                    if success {
                        print("✅ Passport deleted successfully")
                    } else {
                        print("❌ Failed to delete passport")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Enhanced Clear All with Progress Tracking
    
    func clearAllData() async {
        let context = persistentContainer.viewContext
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            context.perform {
                Task {
                    do {
                        print("🧹 Clearing all data...")
                        
                        // Get count for progress tracking
                        let passportRequest: NSFetchRequest<SavedPassport> = SavedPassport.fetchRequest()
                        let passportCount = try context.count(for: passportRequest)
                        
                        let photoRequest: NSFetchRequest<PassportPhoto> = PassportPhoto.fetchRequest()
                        let photoCount = try context.count(for: photoRequest)
                        
                        print("🗑️ Deleting \(passportCount) passports and \(photoCount) photos...")
                        
                        // Delete all SavedPassport entities (photos will be cascade deleted)
                        let deletePassportsRequest = NSBatchDeleteRequest(fetchRequest: SavedPassport.fetchRequest())
                        deletePassportsRequest.resultType = .resultTypeObjectIDs
                        
                        let passportResult = try context.execute(deletePassportsRequest) as? NSBatchDeleteResult
                        if let objectIDs = passportResult?.result as? [NSManagedObjectID] {
                            let changes = [NSDeletedObjectsKey: objectIDs]
                            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                            print("✅ Batch deleted \(objectIDs.count) passports")
                        }
                        
                        // Delete any orphaned photos (safety cleanup)
                        let deletePhotosRequest = NSBatchDeleteRequest(fetchRequest: PassportPhoto.fetchRequest())
                        deletePhotosRequest.resultType = .resultTypeObjectIDs
                        
                        let photoResult = try context.execute(deletePhotosRequest) as? NSBatchDeleteResult
                        if let objectIDs = photoResult?.result as? [NSManagedObjectID] {
                            let changes = [NSDeletedObjectsKey: objectIDs]
                            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                            print("✅ Batch deleted \(objectIDs.count) photos")
                        }
                        
                        // Final save
                        let success = await self.saveContext()
                        if success {
                            print("✅ All data cleared successfully")
                        } else {
                            print("❌ Failed to clear data")
                        }
                        
                    } catch {
                        print("❌ Error clearing data: \(error)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    deinit {
        print("🗃️ CoreDataManager deallocated")
    }
}

// MARK: - Enhanced SavedPassport Extensions for v1.5

extension SavedPassport {
    
    /// Enhanced passport data reconstruction for v1.5 compatibility
    var completePassportData: PassportData? {
        guard let rawMRZ = self.rawMRZ,
              let parsedMRZ = MRZParser.parse(rawMRZ) else {
            print("❌ Cannot reconstruct MRZ data")
            return nil
        }
        
        // Reconstruct personal details from JSON
        var personalDetails: PersonalDetails?
        if let personalDetailsJSON = self.personalDetailsJSON,
           let data = personalDetailsJSON.data(using: .utf8) {
            do {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                personalDetails = PersonalDetails(
                    fullName: dict["fullName"] ?? "Unknown",
                    surname: dict["surname"] ?? "",
                    givenNames: dict["givenNames"] ?? "",
                    nationality: dict["nationality"] ?? "",
                    dateOfBirth: dict["dateOfBirth"] ?? "",
                    placeOfBirth: dict["placeOfBirth"]?.isEmpty == false ? dict["placeOfBirth"] : nil,
                    sex: dict["sex"] ?? "",
                    documentNumber: dict["documentNumber"] ?? "",
                    documentType: dict["documentType"] ?? "",
                    issuingCountry: dict["issuingCountry"] ?? "",
                    expiryDate: dict["expiryDate"] ?? ""
                )
            } catch {
                print("⚠️ Failed to decode personal details JSON: \(error)")
            }
        }
        
        // Reconstruct additional info
        var additionalInfo: [String: String] = [:]
        if let additionalInfoJSON = self.additionalInfoJSON,
           let data = additionalInfoJSON.data(using: .utf8) {
            do {
                additionalInfo = try JSONDecoder().decode([String: String].self, from: data)
            } catch {
                print("⚠️ Failed to decode additional info JSON: \(error)")
            }
        }
        
        // Reconstruct reading errors
        var readingErrors: [String] = []
        if let readingErrorsJSON = self.readingErrorsJSON,
           let data = readingErrorsJSON.data(using: .utf8) {
            do {
                readingErrors = try JSONDecoder().decode([String].self, from: data)
            } catch {
                print("⚠️ Failed to decode reading errors JSON: \(error)")
            }
        }
        
        // Reconstruct photo
        var photo: UIImage?
        if let passportPhoto = self.photo,
           let imageData = passportPhoto.imageData {
            photo = UIImage(data: imageData)
        }
        
        return PassportData(
            mrzData: parsedMRZ,
            personalDetails: personalDetails,
            photo: photo,
            additionalInfo: additionalInfo,
            chipAuthSuccess: self.chipAuthSuccess, // Critical for v1.5 crypto overlay
            bacSuccess: self.bacSuccess,
            readingErrors: readingErrors
        )
    }
}
