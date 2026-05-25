import Foundation
import CoreData

extension Geraet {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Geraet> {
        return NSFetchRequest<Geraet>(entityName: "Geraet")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var anschaffungsKosten: Double
    @NSManaged var nutzungsdauerStunden: Int32
    @NSManaged var notiz: String?

    // Kosten pro Betriebsstunde (lineare Abschreibung)
    var kostenProStunde: Double {
        guard nutzungsdauerStunden > 0 else { return 0 }
        return anschaffungsKosten / Double(nutzungsdauerStunden)
    }
}

extension Geraet: Identifiable {}
