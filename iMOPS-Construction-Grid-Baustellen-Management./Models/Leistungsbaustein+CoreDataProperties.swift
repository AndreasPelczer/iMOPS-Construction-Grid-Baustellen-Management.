import Foundation
import CoreData

extension Leistungsbaustein {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Leistungsbaustein> {
        return NSFetchRequest<Leistungsbaustein>(entityName: "Leistungsbaustein")
    }

    @NSManaged var id: UUID?
    @NSManaged var leistung: String?          // die Bezeichnung, = Knoten-Text
    @NSManaged var einheit: String?
    @NSManaged var maurerStunden: Double      // h je Einheit
    @NSManaged var helferStunden: Double      // h je Einheit
    @NSManaged var kostenGruppeNummer: String?
    @NSManaged var quelle: String?            // "prof" | "manuell"
    @NSManaged var erstelltAm: Date?
    @NSManaged var verwendungen: Int32        // wie oft gepickt — häufige zuerst

    /// Kurzform für die Anzeige: „0,5 Maurer + 1,5 Helfer h/psch".
    var aufwandAnzeige: String {
        let m = maurerStunden.formatted(.number.precision(.fractionLength(0...2)))
        let h = helferStunden.formatted(.number.precision(.fractionLength(0...2)))
        return "\(m) Maurer + \(h) Helfer h/\(einheit ?? "E")"
    }
}

extension Leistungsbaustein: Identifiable {}
