import Foundation
import CoreData

extension Aufmass {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Aufmass> {
        return NSFetchRequest<Aufmass>(entityName: "Aufmass")
    }

    @NSManaged var id: UUID?
    @NSManaged var istMenge: Double
    @NSManaged var istEinheit: String?
    @NSManaged var erstelltAm: Date?
    @NSManaged var quelleRaw: String?
    @NSManaged var fotoData: Data?
    @NSManaged var notiz: String?
    @NSManaged var lvPosition: LVPosition?

    // Getypter Zugriff über den rohen String — Mirror des MengenQuelle/MaterialQuelle-
    // Musters. rawValue == Wire-Format, damit ein späterer Import verlustfrei round-trippt.
    var quelle: AufmassQuelle {
        get { AufmassQuelle(rawValue: quelleRaw ?? "manuell") ?? .manuell }
        set { quelleRaw = newValue.rawValue }
    }
}

extension Aufmass: Identifiable {}

// Woher die gemessene Ist-Menge stammt. Bewusst getrennt von MengenQuelle (LVPosition —
// Soll/Schätzung) und MaterialQuelle (Preis): hier geht es um die Herkunft der echten
// MESSUNG (Buch Kap 2 — ein Wort, eine Bedeutung).
enum AufmassQuelle: String, CaseIterable {
    case manuell      // Polier-Eintragung von Hand (Default in Welle 5.1)
    case buildiq      // foto-erkannt — kommt in Welle 5.3
    case lieferschein // Lieferschein-OCR — später
    case importiert   // CSV/Excel-Import — später
}
