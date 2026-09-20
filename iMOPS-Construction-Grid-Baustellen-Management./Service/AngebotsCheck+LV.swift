import Foundation
import CoreData

// MARK: - AngebotsCheck ⨯ LV (Adapter)
// Übersetzt echte LV-Positionen in den reinen Kern. Nur hier wird der effektive
// Einheitspreis geholt und die Alternative-Kennung gelesen.

extension AngebotsCheck {

    static func pruefe(positionen: [LVPosition]) -> [AngebotsLuecke] {
        pruefe(positionen.map { p in
            AngebotsPosten(
                id: p.objectID.uriRepresentation().absoluteString,
                bezeichnung: p.bezeichnung ?? "—",
                einheit: p.einheit ?? "",
                menge: p.menge,
                einzelpreis: LVKalkulator.effektiverEP(for: p),
                istAlternative: LVPositionHelper.isAlternative(p))
        })
    }
}
