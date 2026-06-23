import Foundation
import CoreData

extension Aufmass {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Aufmass> {
        NSFetchRequest<Aufmass>(entityName: "Aufmass")
    }

    @NSManaged public var erstelltAm: Date?
    @NSManaged public var fotoData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var istEinheit: String?
    @NSManaged public var istMenge: Double
    @NSManaged public var notiz: String?
    @NSManaged public var quelleRaw: String?
    @NSManaged var lvPosition: LVPosition?

    var quelle: AufmassQuelle {
        get { AufmassQuelle(rawValue: quelleRaw ?? "manuell") ?? .manuell }
        set { quelleRaw = newValue.rawValue }
    }
}

extension Aufmass: Identifiable {}

enum AufmassQuelle: String, Codable, CaseIterable {
    case manuell
    case importiert
    case buildiq
}
