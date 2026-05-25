import Foundation
import CoreData

extension Lohnsatz {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Lohnsatz> {
        return NSFetchRequest<Lohnsatz>(entityName: "Lohnsatz")
    }

    @NSManaged var id: UUID?
    @NSManaged var qualifikation: String?
    @NSManaged var stundenlohn: Double
    @NSManaged var zuschlagFaktor: Double

    // Brutto-EK pro Stunde: Stundenlohn × Zuschlag (Lohnnebenkosten + Verwaltung)
    var berechnungBruttoEK: Double {
        stundenlohn * zuschlagFaktor
    }
}

extension Lohnsatz: Identifiable {}
