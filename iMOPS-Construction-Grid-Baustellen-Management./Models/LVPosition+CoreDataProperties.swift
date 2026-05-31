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
    @NSManaged var event: Event?

    // Kalkulations-Relationships
    @NSManaged var kalkMaterialien: NSSet?
    @NSManaged var kalkLohn: NSSet?
    @NSManaged var kalkGeraete: NSSet?
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
