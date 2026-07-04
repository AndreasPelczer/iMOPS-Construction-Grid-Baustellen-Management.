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
}
extension Voraussetzung: Identifiable {}

enum VoraussetzungsTyp: String { case automatisch, manuell }
extension Voraussetzung {
    var art: VoraussetzungsTyp { VoraussetzungsTyp(rawValue: typ ?? "") ?? .manuell }
}
