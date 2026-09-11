//
//  Event+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//

import Foundation
import CoreData

@objc(Event)
class Event: NSManagedObject {
}

extension Event {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
    @NSManaged var eventEndTime: Date?
    @NSManaged var eventNumber: String?
    @NSManaged var eventStartTime: Date?
    @NSManaged var extras: String?
    @NSManaged var location: String?
    @NSManaged var name: String?
    @NSManaged var notes: String?
    @NSManaged var setupTime: Date?
    @NSManaged var startTime: Date?
    @NSManaged var timeStamp: Date?
    @NSManaged var title: String?
    @NSManaged var bauherr: String?

    // MARK: - Anschrift des Rechnungsempfaengers
    //
    // **Eine Rechnung braucht die vollstaendige Anschrift des Leistungsempfaengers**
    // (§ 14 UStG) — ohne sie kann der Kunde keine Vorsteuer ziehen und schickt sie
    // zurueck. Bis hierher kannte das Modell nur `bauherr` (einen Namen) und
    // `location` (die Baustelle — nicht der Empfaenger). Die XRechnung trug darum
    // als Kaeufer den `title` der Baustelle.
    //
    // Optional, weil ein Angebot noch ohne auskommt: erst die Rechnung braucht sie.
    @NSManaged var bauherrStrasse: String?
    @NSManaged var bauherrPLZ: String?
    @NSManaged var bauherrOrt: String?

    /// Anschrift als Block, leere Zeilen fallen weg — fuer Briefkopf und Rechnung.
    var bauherrAnschrift: [String] {
        [bauherr, bauherrStrasse, [bauherrPLZ, bauherrOrt].compactMap { $0 }
            .filter { !$0.isEmpty }.joined(separator: " ")]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Reicht die Anschrift fuer eine ordnungsgemaesse Rechnung?
    /// Name + Strasse + Ort — die Pruefung, die vor dem Versand steht.
    var anschriftIstVollstaendig: Bool {
        [bauherr, bauherrStrasse, bauherrOrt]
            .allSatisfy { !($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }
    @NSManaged var architekt: String?
    @NSManaged var baugenehmigungNr: String?
    @NSManaged var jobs: NSSet?
    @NSManaged var maengel: NSSet?
    /// Bautagesberichte dieser Baustelle, chronologisch geführt.
    @NSManaged var bautagesberichte: NSSet?
    @NSManaged var lvPositionen: NSSet?
    // Welle 9 — Bau-Hierarchie: Gebäude dieser Baustelle (Relation im Modell definiert,
    // Inverse Gebaeude.event). Getypter Accessor freigelegt für den Hierarchie-Helfer.
    @NSManaged var gebaeude: NSSet?

}

// MARK: Generated accessors for bautagesberichte
extension Event {

    @objc(addBautagesberichteObject:)
    @NSManaged func addToBautagesberichte(_ value: Bautagesbericht)

    @objc(removeBautagesberichteObject:)
    @NSManaged func removeFromBautagesberichte(_ value: Bautagesbericht)

    @objc(addBautagesberichte:)
    @NSManaged func addToBautagesberichte(_ values: NSSet)

    @objc(removeBautagesberichte:)
    @NSManaged func removeFromBautagesberichte(_ values: NSSet)

}

// MARK: Generated accessors for maengel
extension Event {

    @objc(addMaengelObject:)
    @NSManaged func addToMaengel(_ value: Mangel)

    @objc(removeMaengelObject:)
    @NSManaged func removeFromMaengel(_ value: Mangel)

    @objc(addMaengel:)
    @NSManaged func addToMaengel(_ values: NSSet)

    @objc(removeMaengel:)
    @NSManaged func removeFromMaengel(_ values: NSSet)

}

// MARK: Generated accessors for jobs
extension Event {

    @objc(addJobsObject:)
    @NSManaged func addToJobs(_ value: Auftrag)

    @objc(removeJobsObject:)
    @NSManaged func removeFromJobs(_ value: Auftrag)

    @objc(addJobs:)
    @NSManaged func addToJobs(_ values: NSSet)

    @objc(removeJobs:)
    @NSManaged func removeFromJobs(_ values: NSSet)

}

// MARK: Generated accessors for lvPositionen
extension Event {

    @objc(addLvPositionenObject:)
    @NSManaged func addToLvPositionen(_ value: LVPosition)

    @objc(removeLvPositionenObject:)
    @NSManaged func removeFromLvPositionen(_ value: LVPosition)

    @objc(addLvPositionen:)
    @NSManaged func addToLvPositionen(_ values: NSSet)

    @objc(removeLvPositionen:)
    @NSManaged func removeFromLvPositionen(_ values: NSSet)

}

extension Event: Identifiable {}
