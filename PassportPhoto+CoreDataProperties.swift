//
//  PassportPhoto+CoreDataProperties.swift
//  ScanMyID
//
//  Created by Bojan Mijic on 16.07.2025.
//
//

import Foundation
import CoreData


extension PassportPhoto {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PassportPhoto> {
        return NSFetchRequest<PassportPhoto>(entityName: "PassportPhoto")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var passport: SavedPassport?

}

extension PassportPhoto : Identifiable {

}
