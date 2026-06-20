//
//  Gebaeude+CoreDataClass.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 20.06.26.
//
import Foundation
import CoreData

@objc(Gebaeude)
class Gebaeude: NSManagedObject {}

extension Gebaeude {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Gebaeude> {
        return NSFetchRequest<Gebaeude>(entityName: "Gebaeude")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var reihenfolge: Int16
    @NSManaged var event: Event?
    @NSManaged var geschosse: NSSet?
}

extension Gebaeude {
    @objc(addGeschosseObject:)
    @NSManaged func addToGeschosse(_ value: Geschoss)

    @objc(removeGeschosseObject:)
    @NSManaged func removeFromGeschosse(_ value: Geschoss)

    @objc(addGeschosse:)
    @NSManaged func addToGeschosse(_ values: NSSet)

    @objc(removeGeschosse:)
    @NSManaged func removeFromGeschosse(_ values: NSSet)
}

extension Gebaeude : Identifiable {}
