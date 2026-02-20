//
//  CDLexikonEntry+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//

import Foundation
internal import CoreData


extension CDLexikonEntry {

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDLexikonEntry> {
        return NSFetchRequest<CDLexikonEntry>(entityName: "CDLexikonEntry")
    }

    @NSManaged var beschreibung: String?
    @NSManaged var code: String?
    @NSManaged var details: String?
    @NSManaged var kategorie: String?
    @NSManaged var name: String?

}

extension CDLexikonEntry : Identifiable {

}
