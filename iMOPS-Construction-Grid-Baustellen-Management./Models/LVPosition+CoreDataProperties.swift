import Foundation
import CoreData

extension LVPosition {

    @nonobjc class func fetchRequest() -> NSFetchRequest<LVPosition> {
        return NSFetchRequest<LVPosition>(entityName: "LVPosition")
    }

    @NSManaged var posNr: String?
    @NSManaged var bezeichnung: String?
    @NSManaged var menge: Double
    @NSManaged var einheit: String?
    @NSManaged var kostenGruppeNummer: String?
    @NSManaged var artikelNummer: String?
    @NSManaged var lieferant: String?
    @NSManaged var wagnisGewinnProzent: Double
    @NSManaged var bgkProzent: Double
    @NSManaged var mengenQuelleRaw: String?
    @NSManaged var event: Event?

    // Kalkulations-Relationships
    @NSManaged var kalkMaterialien: NSSet?
    @NSManaged var kalkLohn: NSSet?
    @NSManaged var kalkGeraete: NSSet?

    // MARK: - Mengen-Quelle (gemessen/geschätzt — Welle-9-Fundament)
    // Mirror des KalkMaterial-Musters: roher String in Core Data, getypter Enum-Zugriff.
    var mengenQuelle: MengenQuelle {
        get { MengenQuelle(rawValue: mengenQuelleRaw ?? "manuell") ?? .manuell }
        set { mengenQuelleRaw = newValue.rawValue }
    }

    // Ist die Menge ein Schätz-/Planwert (noch nicht belastbar gemessen)?
    var istGeschaetzt: Bool { mengenQuelle.istGeschaetzt }
}

// MARK: - Typed Accessors

extension LVPosition {

    var materialArray: [PositionMaterial] {
        (kalkMaterialien as? Set<PositionMaterial>)?.sorted { ($0.materialName ?? "") < ($1.materialName ?? "") } ?? []
    }

    var lohnArray: [PositionLohn] {
        (kalkLohn as? Set<PositionLohn>)?.sorted { ($0.qualifikation ?? "") < ($1.qualifikation ?? "") } ?? []
    }

    var geraeteArray: [PositionGeraet] {
        (kalkGeraete as? Set<PositionGeraet>)?.sorted { ($0.geraetName ?? "") < ($1.geraetName ?? "") } ?? []
    }

    // Ob fuer diese Position eine Tiefenkalkulation existiert
    var hatKalkulation: Bool {
        !materialArray.isEmpty || !lohnArray.isEmpty || !geraeteArray.isEmpty
    }
}

extension LVPosition: Identifiable {}

// Quelle der MENGEN-Angabe einer LV-Position — getrennt von KalkMaterial.MaterialQuelle,
// weil es hier um die Herkunft der Menge geht (gemessen/geschätzt), nicht um den Preis.
// rawValue == Wire-Format der Box (ExtractLVPosition.quelle), damit der Import
// verlustfrei round-trippt.
enum MengenQuelle: String, CaseIterable {
    case statik     = "statik_tabelle"  // aus der Statik-Tabelle — belastbar/hart
    case bplan      = "b-plan"          // aus dem Bebauungsplan — Planwert
    case schaetzung = "schaetzung"      // geschätzt
    case manuell    = "manuell"         // von Hand eingetragen

    // Belastbar ist heute nur die harte Statik-Tabelle (Box-Etikett "hart"). Alles
    // andere bleibt bis zur BuildIQ-Messung ein Schätzwert und wird in der
    // Voraussetzungs-Ampel (Welle 9) andersfarbig dargestellt. Buch Kap 6:
    // Zustand "gemessen" ≠ Zustand "geschätzt". Unbekannte Quelle → defensiv geschätzt.
    var istGeschaetzt: Bool { self != .statik }
}
