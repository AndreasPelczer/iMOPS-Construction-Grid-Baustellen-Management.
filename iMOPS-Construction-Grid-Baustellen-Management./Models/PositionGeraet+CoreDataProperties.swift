import Foundation
import CoreData

extension PositionGeraet {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PositionGeraet> {
        return NSFetchRequest<PositionGeraet>(entityName: "PositionGeraet")
    }

    @NSManaged var id: UUID?
    @NSManaged var stunden: Double
    @NSManaged var geraetName: String?
    @NSManaged var kostenProStunde: Double
    @NSManaged var position: LVPosition?

    // Geraetekosten dieses Eintrags pro Positions-Einheit
    var kostenProEinheit: Double {
        kostenProStunde * stunden
    }
}

extension PositionGeraet: Identifiable {}
