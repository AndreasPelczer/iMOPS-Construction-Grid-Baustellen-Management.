//
//  Auftrag+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//
//

import Foundation
import CoreData


extension Auftrag {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Auftrag> {
        return NSFetchRequest<Auftrag>(entityName: "Auftrag")
    }

    @NSManaged var deliveryTemperature: Bool
    @NSManaged var employeeName: String?
    @NSManaged var isCompleted: Bool
    @NSManaged var kostenGruppeBezeichnung: String?
    @NSManaged var kostenGruppeNummer: String?
    @NSManaged var lastStartTime: Date?
    @NSManaged var processingDetails: String?
    @NSManaged var statusRawValue: String?
    @NSManaged var storageLocation: String?
    @NSManaged var storageNote: String?
    @NSManaged var totalProcessingTime: Double
    @NSManaged var event: Event?
    @NSManaged var extras: String?

    // Grap8 — Gegenstücke zu Voraussetzung.quelle / .auftrag.
    // Löschregel Cascade in beide Richtungen: eine Kante, deren Auftrag gelöscht
    // wurde, fiele sonst auf das gespeicherte `erfuellt` (Default NO) zurück und
    // würde den abhängigen Schritt für immer blockieren.
    /// Kanten, in denen DIESER Auftrag die Quelle ist (er blockiert andere).
    @NSManaged var istVoraussetzungFuer: NSSet?
    /// Kanten, die zu DIESEM Auftrag gehören (er wartet auf andere).
    @NSManaged var voraussetzungen: NSSet?


}

extension Auftrag : Identifiable {

}
