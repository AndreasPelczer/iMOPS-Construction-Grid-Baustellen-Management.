import Foundation
import CoreData

extension Mangel {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Mangel> {
        NSFetchRequest<Mangel>(entityName: "Mangel")
    }

    @NSManaged var id: UUID?
    @NSManaged var titel: String?
    @NSManaged var beschreibung: String?
    @NSManaged var ort: String?
    @NSManaged var gewerk: String?
    @NSManaged var kostenGruppeNummer: String?
    @NSManaged var statusRawValue: String?
    @NSManaged var frist: Date?
    @NSManaged var erfasstAm: Date?
    @NSManaged var erfasstVon: String?
    @NSManaged var fotoPfad: String?
    @NSManaged var schwere: String?
    @NSManaged var event: Event?
}

extension Mangel: Identifiable {}
