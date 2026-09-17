import Foundation
import CoreData

extension PositionGeraet {

    @nonobjc class func fetchRequest() -> NSFetchRequest<PositionGeraet> {
        return NSFetchRequest<PositionGeraet>(entityName: "PositionGeraet")
    }

    @NSManaged var id: UUID?
    @NSManaged var stunden: Double
    @NSManaged var geraetName: String?
    @NSManaged var kostenProStunde: Double
    @NSManaged var position: LVPosition?
    // Pauschal/Fahrten statt Stunden: dann ist `stunden` die ABSOLUTE Anzahl (z.B. 6 Fahrten)
    // für die ganze Position und `kostenProStunde` der Preis JE Einheit (z.B. 120 €/Fahrt).
    @NSManaged var pauschal: Bool
    @NSManaged var einheit: String?        // Label der Anzahl-Einheit: "h" (Standard), "Fahrt", "Tag" …

    /// Die Zähl-Einheit fürs Anzeigen ("h", "Fahrt", …).
    var zaehlEinheit: String { (einheit?.isEmpty == false) ? einheit! : "h" }

    /// Gesamtbetrag dieses Postens für die ganze Position (pauschal: Anzahl × Preis; sonst je-Einheit × Menge).
    var kostenGesamt: Double {
        pauschal ? kostenProStunde * stunden : kostenProEinheit * (position?.menge ?? 0)
    }

    // Geraetekosten dieses Eintrags pro Positions-Einheit.
    // Pauschal (Fahrten/Pauschale): Gesamt (Anzahl × Preis) ÷ Menge — hebt das spätere ×Menge
    // in LVKalkulator auf, sodass die Engine unverändert korrekt bleibt.
    var kostenProEinheit: Double {
        if pauschal {
            let m = position?.menge ?? 0
            return m > 0 ? (kostenProStunde * stunden) / m : 0
        }
        return kostenProStunde * stunden
    }
}

extension PositionGeraet: Identifiable {}
