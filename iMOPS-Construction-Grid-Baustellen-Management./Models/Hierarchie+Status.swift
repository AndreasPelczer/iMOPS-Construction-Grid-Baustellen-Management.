import Foundation
import CoreData

// Welle 9 Stufe C, §4 — rechnende Logik. NICHTS davon wird persistiert:
// automatische Voraussetzungen und der Gebäude-Freigabe-Rollup sind live berechnet
// (eine Wahrheit, kein stale State). Nur die manuellen Voraussetzungen + die
// Geschoss-Freigabe selbst liegen in Core Data.

// MARK: - Geschoss: Mengen-/Schätz-Status

extension Geschoss {
    var lvPositionenArray: [LVPosition] {
        (lvPositionen?.allObjects as? [LVPosition]) ?? []
    }

    /// Positionen dieses Geschosses, deren Menge noch geschätzt (nicht harte Statik)
    /// und noch nicht per Aufmaß gemessen ist.
    var geschaetztOffen: Int {
        lvPositionenArray.filter { $0.istGeschaetzt && !$0.hatAufmass }.count
    }

    var voraussetzungenArray: [Voraussetzung] {
        ((voraussetzungen?.allObjects as? [Voraussetzung]) ?? [])
            .sorted { $0.reihenfolge < $1.reihenfolge }
    }

    var manuelleVoraussetzungen: [Voraussetzung] {
        voraussetzungenArray.filter { $0.art == .manuell }
    }
}

// MARK: - Automatische Voraussetzungen (Code-Liste, live berechnet)

struct AutoVoraussetzung: Identifiable {
    let name: String
    let erfuellt: (Geschoss) -> Bool
    var id: String { name }
}

enum Welle9AutoKatalog {
    static let alle: [AutoVoraussetzung] = [
        AutoVoraussetzung(name: "Keine geschätzten Mengen offen") { $0.geschaetztOffen == 0 },
        AutoVoraussetzung(name: "Geschoss hat Positionen") { !$0.lvPositionenArray.isEmpty },
    ]
}

// MARK: - Geschoss-Reife (auto ∪ manuell)

extension Geschoss {
    var autoAlleErfuellt: Bool {
        Welle9AutoKatalog.alle.allSatisfy { $0.erfuellt(self) }
    }
    var manuellAlleErfuellt: Bool {
        manuelleVoraussetzungen.allSatisfy { $0.erfuellt }
    }
    /// Reif = alle Voraussetzungen (automatisch berechnet ∪ manuell abgehakt) erfüllt.
    var istReif: Bool { autoAlleErfuellt && manuellAlleErfuellt }

    var voraussetzungenErfuellt: Int {
        Welle9AutoKatalog.alle.filter { $0.erfuellt(self) }.count
            + manuelleVoraussetzungen.filter { $0.erfuellt }.count
    }
    var voraussetzungenGesamt: Int {
        Welle9AutoKatalog.alle.count + manuelleVoraussetzungen.count
    }
}

// MARK: - Gebäude-Freigabe = abgeleiteter Rollup (NICHT persistiert)

extension Gebaeude {
    var geschosseArray: [Geschoss] {
        ((geschosse?.allObjects as? [Geschoss]) ?? [])
            .sorted { $0.reihenfolge < $1.reihenfolge }
    }
    /// Grün, wenn es Geschosse gibt UND alle freigegeben sind.
    var freigegeben: Bool {
        !geschosseArray.isEmpty && geschosseArray.allSatisfy { $0.freigegeben }
    }
}
