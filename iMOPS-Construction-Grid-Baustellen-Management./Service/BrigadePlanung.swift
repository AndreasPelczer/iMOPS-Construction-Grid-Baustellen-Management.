//
//  BrigadePlanung.swift
//  Die Brücke Kalkulation → Brigade (Nordstern-Stufe 5): aus den Lohnstunden des LV
//  (Aufwandswert × Menge, `LVKalkulator.gesamtStunden`) wird der Personalbedarf einer
//  Baustelle — Mannstunden → Manntage → Arbeitstage bei N Leuten.
//
//  EHRLICH (Tao, Zustand statt Behauptung): gezählt werden nur Positionen, die einen
//  Aufwandswert (Lohn h/Einheit) tragen. Positionen ohne Aufwandswert zählen 0 — sie
//  werden separat ausgewiesen, damit die Summe nicht fälschlich niedrig gelesen wird.
//

import Foundation

struct BrigadePlanung {

    /// Regel-Arbeitszeit je Person und Tag (Stunden). Später ggf. in die Stammdaten.
    static let stundenJeTag: Double = 8.0

    let mannstunden: Double
    let positionenGesamt: Int
    let positionenOhneAufwand: Int      // keine Lohnstunden hinterlegt → tragen 0 bei

    /// Manntage = Mannstunden ÷ Stunden je Tag.
    var manntage: Double { mannstunden / Self.stundenJeTag }

    /// Kalendertage bei `leute` Personen (parallel), oder nil bei 0 Leuten.
    func arbeitstage(beiLeuten leute: Int) -> Double? {
        leute > 0 ? manntage / Double(leute) : nil
    }

    /// Ob noch Aufwandswerte fehlen (dann ist die Summe unvollständig).
    var unvollstaendig: Bool { positionenOhneAufwand > 0 }

    /// Personalbedarf aus den LV-Positionen einer Baustelle.
    static func fuer(positionen: [LVPosition]) -> BrigadePlanung {
        let stunden = LVKalkulator.gesamtStunden(positionen: positionen)
        let ohne = positionen.filter { pos in
            pos.lohnArray.reduce(0.0) { $0 + $1.stunden } == 0
        }.count
        return BrigadePlanung(mannstunden: stunden,
                              positionenGesamt: positionen.count,
                              positionenOhneAufwand: ohne)
    }
}
