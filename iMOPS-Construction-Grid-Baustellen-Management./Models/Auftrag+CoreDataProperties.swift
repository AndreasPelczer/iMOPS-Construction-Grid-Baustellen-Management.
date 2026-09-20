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
    // Leinwand-Position (Grap8-Canvas). Optional: nil = noch nie verschoben → Auto-Layout.
    @NSManaged var posX: NSNumber?
    @NSManaged var posY: NSNumber?
    @NSManaged var statusRawValue: String?
    @NSManaged var storageLocation: String?
    @NSManaged var storageNote: String?
    @NSManaged var totalProcessingTime: Double
    @NSManaged var dauerTage: Double   // Zeit im Canvas: Arbeitsdauer in Tagen (0 = Meilenstein)
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

    // Grap8 — Draht 1 (Ast 2): der Knoten (Auftrag) bekommt eine EIGENE Kalkulations-
    // Position. Bisher gab es zwischen Auftrag und LVPosition keine Beziehung
    // (Grap8Graph.swift: „vom Auftrag aus führt kein Weg zur LVPosition"); die
    // Kalkulation hing nur an Event. Optional + Nullify: ein Auftrag ohne Position
    // verhält sich wie bisher, und wird die Position gelöscht, bleibt der Auftrag.
    @NSManaged var lvPosition: LVPosition?


}

extension Auftrag : Identifiable {

}
