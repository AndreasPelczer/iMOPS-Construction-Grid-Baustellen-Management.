import Foundation
import CoreData

// MARK: - PreisWaechter ⨯ LV (Adapter)
//
// Der dünne Übersetzer zwischen den echten LV-Positionen (Core Data) und dem
// reinen Rechenkern `PreisWaechter` (der nichts von Core Data weiß, damit er
// testbar bleibt). Hier — und NUR hier — wird der effektive Einheitspreis geholt.

extension PreisWaechter {

    /// Prüft die Einheitspreise echter LV-Positionen auf Ausreißer / Komma-Fehler.
    /// Positionen ohne Preis (EP = 0, noch nicht kalkuliert) werden übersprungen —
    /// über 0 zu urteilen wäre geraten.
    static func pruefe(positionen: [LVPosition]) -> [PreisBefund] {
        let punkte: [PreisPunkt] = positionen.compactMap { p in
            let ep = LVKalkulator.effektiverEP(for: p)
            guard ep > 0 else { return nil }
            return PreisPunkt(
                id: p.objectID.uriRepresentation().absoluteString,
                bezeichnung: p.bezeichnung ?? "—",
                einheit: p.einheit ?? "",
                einzelpreis: ep)
        }
        return pruefe(punkte)
    }
}
