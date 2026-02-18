//
//  CDLexikonEntry+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//

import Foundation
import CoreData


extension CDLexikonEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDLexikonEntry> {
        return NSFetchRequest<CDLexikonEntry>(entityName: "CDLexikonEntry")
    }

    @NSManaged public var beschreibung: String?
    @NSManaged public var code: String?
    @NSManaged public var details: String?
    @NSManaged public var kategorie: String?
    @NSManaged public var name: String?

}

extension CDLexikonEntry : Identifiable {

}
