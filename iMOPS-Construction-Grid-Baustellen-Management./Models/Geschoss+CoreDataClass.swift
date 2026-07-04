//
//  Geschoss+CoreDataClass.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 20.06.26.
//
import Foundation
import CoreData

@objc(Geschoss)
class Geschoss: NSManagedObject {}

extension Geschoss {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Geschoss> {
        return NSFetchRequest<Geschoss>(entityName: "Geschoss")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var reihenfolge: Int16
    @NSManaged var gebaeude: Gebaeude?
    @NSManaged var lvPositionen: NSSet?
    // Welle 9 Stufe C — Freigabe (persistiert) + Voraussetzungen (nur manuelle gespeichert).
    @NSManaged var freigegeben: Bool
    @NSManaged var freigegebenAm: Date?
    @NSManaged var freigegebenVon: String?
    @NSManaged var voraussetzungen: NSSet?
}

extension Geschoss {
    @objc(addVoraussetzungenObject:)
    @NSManaged func addToVoraussetzungen(_ value: Voraussetzung)

    @objc(removeVoraussetzungenObject:)
    @NSManaged func removeFromVoraussetzungen(_ value: Voraussetzung)

    @objc(addVoraussetzungen:)
    @NSManaged func addToVoraussetzungen(_ values: NSSet)

    @objc(removeVoraussetzungen:)
    @NSManaged func removeFromVoraussetzungen(_ values: NSSet)
}

extension Geschoss {
    @objc(addLvPositionenObject:)
    @NSManaged func addToLvPositionen(_ value: LVPosition)

    @objc(removeLvPositionenObject:)
    @NSManaged func removeFromLvPositionen(_ value: LVPosition)

    @objc(addLvPositionen:)
    @NSManaged func addToLvPositionen(_ values: NSSet)

    @objc(removeLvPositionen:)
    @NSManaged func removeFromLvPositionen(_ values: NSSet)
}

extension Geschoss : Identifiable {}
