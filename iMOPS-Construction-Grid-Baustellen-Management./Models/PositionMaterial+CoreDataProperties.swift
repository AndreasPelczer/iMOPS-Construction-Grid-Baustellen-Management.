import Foundation
import CoreData

extension PositionMaterial {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PositionMaterial> {
        return NSFetchRequest<PositionMaterial>(entityName: "PositionMaterial")
    }

    @NSManaged var id: UUID?
    @NSManaged var materialName: String?
    @NSManaged var mengeProEinheit: Double
    @NSManaged var einzelpreis: Double
    @NSManaged var verschnittProzent: Double
    @NSManaged var einheit: String?
    @NSManaged var position: LVPosition?

    // Kosten dieses Materials pro Positions-Einheit (inkl. Verschnitt)
    var kostenProEinheit: Double {
        einzelpreis * mengeProEinheit * (1 + verschnittProzent)
    }
}

extension PositionMaterial: Identifiable {}
