//
//  SavedPassport+CoreDataProperties.swift
//  ScanMyID
//
//  Created by Bojan Mijic on 16.07.2025.
//
//

import Foundation
import CoreData


extension SavedPassport {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SavedPassport> {
        return NSFetchRequest<SavedPassport>(entityName: "SavedPassport")
    }

    @NSManaged public var additionalInfoJSON: String?
    @NSManaged public var bacSuccess: Bool
    @NSManaged public var chipAuthSuccess: Bool
    @NSManaged public var documentNumber: String?
    @NSManaged public var expiryDate: String?
    @NSManaged public var fullName: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isAuthenticated: Bool
    @NSManaged public var nationality: String?
    @NSManaged public var personalDetailsJSON: String?
    @NSManaged public var rawMRZ: String?
    @NSManaged public var readingErrorsJSON: String?
    @NSManaged public var scanDate: Date?
    @NSManaged public var photo: PassportPhoto?

}

extension SavedPassport : Identifiable {

}
