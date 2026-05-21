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
    @NSManaged var event: Event?
}

extension LVPosition: Identifiable {}
