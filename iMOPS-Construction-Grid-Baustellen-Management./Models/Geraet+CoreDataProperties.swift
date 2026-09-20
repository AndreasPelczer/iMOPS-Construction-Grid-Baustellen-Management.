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
    @NSManaged var leistung: Double     // Aushubleistung in m³/h (0 = nicht gesetzt → Richtwert)
    @NSManaged var stundensatz: Double  // fester Miet-/Verrechnungssatz €/h (0 = nicht gesetzt → Abschreibung)

    // Kosten pro Betriebsstunde.
    // Ist ein fester Stundensatz gesetzt (Fremdgerät/Miete, z. B. aus dem Firma-Katalog),
    // gilt DER. Sonst lineare Abschreibung Anschaffung ÷ Nutzungsdauer (eigenes Gerät).
    var kostenProStunde: Double {
        if stundensatz > 0 { return stundensatz }
        guard nutzungsdauerStunden > 0 else { return 0 }
        return anschaffungsKosten / Double(nutzungsdauerStunden)
    }
}

extension Geraet: Identifiable {}
