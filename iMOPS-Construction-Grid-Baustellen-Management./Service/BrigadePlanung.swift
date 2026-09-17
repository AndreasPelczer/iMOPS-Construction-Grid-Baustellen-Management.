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
    let rollen: [RollenBedarf]          // nach Rolle aufgeschlüsselt (Nordstern: wer wird gebraucht)

    /// Personalbedarf einer einzelnen Rolle (Baggerfahrer, Rohrleger, Helfer …).
    struct RollenBedarf: Identifiable {
        let rolle: String
        let stunden: Double
        var id: String { rolle }
        var manntage: Double { stunden / BrigadePlanung.stundenJeTag }
    }

    /// Manntage = Mannstunden ÷ Stunden je Tag.
    var manntage: Double { mannstunden / Self.stundenJeTag }

    /// Kalendertage bei `leute` Personen (parallel), oder nil bei 0 Leuten.
    func arbeitstage(beiLeuten leute: Int) -> Double? {
        leute > 0 ? manntage / Double(leute) : nil
    }

    /// Ob noch Aufwandswerte fehlen (dann ist die Summe unvollständig).
    var unvollstaendig: Bool { positionenOhneAufwand > 0 }

    // MARK: - Verteilung über die Bauzeit
    //
    // EHRLICH: Ohne echte Vorgänger-Reihenfolge (das ist `Bauablauf`, ein eigener Schritt)
    // erfinden wir KEINE Abfolge „erst Bagger, dann Rohrleger". Was sich sauber sagen lässt,
    // ist die AUSLASTUNG: über die Bauzeit (Baubeginn→Fertigstellung, nur Arbeitstage) müssen
    // die Manntage verteilt werden → Ø wie viele Leute pro Tag, aufgeschlüsselt nach Rolle.

    /// Auslastung einer Rolle über die Bauzeit.
    struct RollenAuslastung: Identifiable {
        let rolle: String
        let manntage: Double
        let personenProTag: Double     // manntage ÷ Arbeitstage (Ø parallele Köpfe dieser Rolle)
        var id: String { rolle }
    }

    /// Verteilung des Personalbedarfs über die Bauzeit.
    struct Bauzeitverteilung {
        let arbeitstage: Int
        let besetzungProTag: Double         // gesamte Manntage ÷ Arbeitstage (Ø Kolonnenstärke/Tag)
        let rollen: [RollenAuslastung]
    }

    /// Verteilt Manntage und Rollen über `arbeitstage`. nil, wenn keine Arbeitstage oder kein Aufwand.
    func verteilung(arbeitstage: Int) -> Bauzeitverteilung? {
        guard arbeitstage > 0, mannstunden > 0 else { return nil }
        let tage = Double(arbeitstage)
        let rl = rollen.map {
            RollenAuslastung(rolle: $0.rolle, manntage: $0.manntage,
                             personenProTag: $0.manntage / tage)
        }
        return Bauzeitverteilung(arbeitstage: arbeitstage,
                                 besetzungProTag: manntage / tage,
                                 rollen: rl)
    }

    /// Arbeitstage (Mo–Fr) zwischen zwei Daten, beide Enden eingeschlossen. 0 bei ungültigem Zeitraum.
    static func arbeitstageZwischen(_ von: Date, _ bis: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: von)
        let ende = cal.startOfDay(for: bis)
        guard ende >= start else { return 0 }
        var tag = start
        var zaehler = 0
        while tag <= ende {
            // Sa=7, So=1 in Gregorian; alles andere ist Arbeitstag.
            let wd = cal.component(.weekday, from: tag)
            if wd != 1 && wd != 7 { zaehler += 1 }
            guard let next = cal.date(byAdding: .day, value: 1, to: tag) else { break }
            tag = next
        }
        return zaehler
    }

    /// Personalbedarf aus den LV-Positionen einer Baustelle.
    static func fuer(positionen: [LVPosition]) -> BrigadePlanung {
        let stunden = LVKalkulator.gesamtStunden(positionen: positionen)
        let ohne = positionen.filter { pos in
            pos.lohnArray.reduce(0.0) { $0 + $1.stunden } == 0
        }.count

        // Nach Rolle aufschlüsseln: Lohnstunden je Einheit × Menge, gruppiert nach Qualifikation.
        // Erst jetzt sinnvoll — der Katalog schreibt echte Rollen (Baggerfahrer/Rohrleger/Helfer).
        var proRolle: [String: Double] = [:]
        for pos in positionen {
            for pl in pos.lohnArray where pl.stunden > 0 {
                let rolle = (pl.qualifikation?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Facharbeiter"
                proRolle[rolle, default: 0] += pl.stunden * pos.menge
            }
        }
        let rollen = proRolle
            .map { RollenBedarf(rolle: $0.key, stunden: $0.value) }
            .sorted { $0.stunden > $1.stunden }

        return BrigadePlanung(mannstunden: stunden,
                              positionenGesamt: positionen.count,
                              positionenOhneAufwand: ohne,
                              rollen: rollen)
    }
}
