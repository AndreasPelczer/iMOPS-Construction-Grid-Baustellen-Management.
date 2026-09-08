import Foundation
import CoreData

@objc(Voraussetzung)
class Voraussetzung: NSManagedObject {}

extension Voraussetzung {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Voraussetzung> {
        NSFetchRequest<Voraussetzung>(entityName: "Voraussetzung")
    }
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var typ: String?
    @NSManaged var erfuellt: Bool
    @NSManaged var reihenfolge: Int16
    @NSManaged var geschoss: Geschoss?

    // Grap8 — die Kante im Schritt→Schritt-Graph. Beide optional, damit eine
    // Voraussetzung ohne `quelle` weiter das manuelle Geschoss-Häkchen bleibt.
    /// Der Schritt, der zuerst fertig sein muss ("Wasser erhitzen").
    @NSManaged var quelle: Auftrag?
    /// Der abhängige Schritt, zu dem diese Voraussetzung gehört ("Nudeln kochen").
    @NSManaged var auftrag: Auftrag?
}
extension Voraussetzung: Identifiable {}

enum VoraussetzungsTyp: String { case automatisch, manuell }
extension Voraussetzung {
    var art: VoraussetzungsTyp { VoraussetzungsTyp(rawValue: typ ?? "") ?? .manuell }
}
