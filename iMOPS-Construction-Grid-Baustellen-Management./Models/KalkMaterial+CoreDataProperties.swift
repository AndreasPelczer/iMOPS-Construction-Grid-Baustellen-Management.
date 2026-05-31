import Foundation
import CoreData

extension KalkMaterial {

    @nonobjc class func fetchRequest() -> NSFetchRequest<KalkMaterial> {
        return NSFetchRequest<KalkMaterial>(entityName: "KalkMaterial")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var einheit: String?
    @NSManaged var preisProEinheit: Double
    @NSManaged var lieferant: String?
    @NSManaged var letzteAktualisierung: Date?
    @NSManaged var quelleRaw: String?
    @NSManaged var verbrauchProM2: Double
    @NSManaged var verschnittProzent: Double

    var quelle: MaterialQuelle {
        get { MaterialQuelle(rawValue: quelleRaw ?? "manuell") ?? .manuell }
        set { quelleRaw = newValue.rawValue }
    }
}

extension KalkMaterial: Identifiable {}

enum MaterialQuelle: String, CaseIterable {
    case manuell
    case gaeb
    case heinze
    case mops
}
