import Foundation
import CoreData

// MARK: - FirmaPreisKatalog (Schritt 2)
//
// Der Firma-Preis-Katalog: für einen Leistungstext ist Goldschmitts fertiger EH-Preis
// lokal hinterlegt (`Leistungsbaustein.einheitspreisVK`, gefüllt per Import). Taucht die
// gleiche Leistung in einem neuen LV auf, bekommt sie diesen bekannten Preis — statt einer
// Schätzung. Raphis Zahl schlägt die Vermutung.
//
// Umsetzung ohne Kopplung an die Rechen-Logik: der Firmenpreis wird als `Angebot`
// hinterlegt; `LVKalkulator.effektiverEP` nimmt Angebote ZUERST, also gewinnt er
// automatisch über Tiefenkalk/Schätzung. Match über Leistungstext + Einheit.

enum FirmaPreisKatalog {

    /// Fertiger Firma-EH-Preis für eine Position (nil = keiner hinterlegt).
    static func preis(fuer pos: LVPosition, in ctx: NSManagedObjectContext) -> Double? {
        guard let bez = pos.bezeichnung, !bez.isEmpty,
              let b = LeistungskatalogService.finde(leistung: bez, einheit: pos.einheit ?? "", in: ctx),
              b.einheitspreisVK > 0 else { return nil }
        return b.einheitspreisVK
    }

    /// Hängt den Firma-Preis als Angebot an die Position. true = Preis gesetzt.
    @discardableResult
    static func anwenden(auf pos: LVPosition, store: AngebotsStore,
                         in ctx: NSManagedObjectContext) -> Bool {
        guard let preis = preis(fuer: pos, in: ctx) else { return false }
        // objectID-Falle: der AngebotsStore-Key muss die PERMANENTE ID sein, sonst findet
        // effektiverEP den Preis nach dem Speichern nicht wieder.
        try? ctx.obtainPermanentIDs(for: [pos])
        let posID = pos.objectID.uriRepresentation().absoluteString
        store.upsert(Angebot(lieferant: "Firma-Katalog", einzelpreis: preis), for: posID)
        return true
    }

    /// Auf alle Positionen einer Baustelle anwenden. Gibt die Zahl gesetzter Firmenpreise.
    @discardableResult
    static func anwendenAufAlle(_ event: Event, store: AngebotsStore,
                                in ctx: NSManagedObjectContext) -> Int {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        return positionen.reduce(0) { $0 + (anwenden(auf: $1, store: store, in: ctx) ? 1 : 0) }
    }
}
