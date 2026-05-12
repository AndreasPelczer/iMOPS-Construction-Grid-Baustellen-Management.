import Foundation
import CoreData

extension LVPosition {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LVPosition> {
        return NSFetchRequest<LVPosition>(entityName: "LVPosition")
    }

    @NSManaged public var posNr: String?
    @NSManaged public var bezeichnung: String?
    @NSManaged public var menge: Double
    @NSManaged public var einheit: String?
    @NSManaged public var kostenGruppeNummer: String?
    @NSManaged public var artikelNummer: String?
    @NSManaged public var lieferant: String?
    @NSManaged public var event: Event?
}

extension LVPosition: Identifiable {}
