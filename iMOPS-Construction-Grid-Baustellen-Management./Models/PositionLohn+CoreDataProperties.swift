import Foundation
import CoreData

extension PositionLohn {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PositionLohn> {
        return NSFetchRequest<PositionLohn>(entityName: "PositionLohn")
    }

    @NSManaged var id: UUID?
    @NSManaged var stunden: Double
    @NSManaged var qualifikation: String?
    @NSManaged var stundenBruttoEK: Double
    @NSManaged var position: LVPosition?

    // Lohnkosten dieses Eintrags pro Positions-Einheit
    var kostenProEinheit: Double {
        stundenBruttoEK * stunden
    }
}

extension PositionLohn: Identifiable {}
