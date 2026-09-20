import Foundation

// MARK: - PreisWaechter (Spike, 20.09.2026)
//
// Fängt die FALSCHE ZAHL, bevor das Angebot rausgeht — kein Bauchgefühl, sondern
// Statistik: jeder Einheitspreis wird mit den GLEICHARTIGEN Positionen (gleiche
// Einheit) verglichen. Zwei Dinge fallen auf:
//   1. Zehnerpotenz-/Komma-Falle  — ein EP ist ~10×/100× (oder 1/10, 1/100) vom
//      Mittel der Nachbarn. Das ist fast immer ein verrutschtes Komma
//      (z. B. 8,02 statt 80,21 — genau die offene Frage beim Stützwinkel).
//   2. Ausreißer — ein EP fällt robust (Median + MAD) aus dem Rahmen.
//
// Warum eine Maschine das tut und ein Mensch selten: der Mensch prüft Zeile für
// Zeile; die Maschine sieht die Verteilung und den einen Wert, der nicht passt.
// Das ist Tao: Nachweis vor Behauptung — die App sagt „prüf diese Zahl", nicht
// „die ist falsch". Der Mensch entscheidet.
//
// Reines Rechenstück (KEIN Core Data) → testbar. Ein dünner Adapter (unten)
// füttert echte LV-Positionen ein, ohne dass der Kern etwas davon weiß.

struct PreisPunkt: Sendable, Equatable {
    let id: String
    let bezeichnung: String
    let einheit: String        // "m2", "m", "St", "m3", "t" …
    let einzelpreis: Double     // EP netto
}

struct PreisBefund: Sendable, Equatable, Identifiable {
    enum Art: Sendable, Equatable { case zehnerpotenz, ausreisser }
    var id: String { punktID }
    let punktID: String
    let bezeichnung: String
    let art: Art
    let einzelpreis: Double
    let referenz: Double        // Median der gleichartigen Positionen
    let faktor: Double          // einzelpreis / referenz
    let hinweis: String
}

enum PreisWaechter {

    /// Verdächtige Einheitspreise finden.
    /// - mindestGruppe: ab wie vielen gleichartigen Positionen überhaupt verglichen wird
    ///   (darunter fehlt die Vergleichsbasis — dann lieber schweigen als raten).
    /// - madSchwelle: robuster Ausreißer-Faktor (Median + MAD). 4.0 = streng, kaum Fehlalarm.
    static func pruefe(_ punkte: [PreisPunkt],
                       mindestGruppe: Int = 4,
                       madSchwelle: Double = 4.0) -> [PreisBefund] {
        var befunde: [PreisBefund] = []
        let gruppen = Dictionary(grouping: punkte.filter { $0.einzelpreis > 0 }) { normEinheit($0.einheit) }

        for (_, gruppe) in gruppen {
            guard gruppe.count >= mindestGruppe else { continue }
            let median = medianOf(gruppe.map { $0.einzelpreis })
            guard median > 0 else { continue }
            let mad = medianOf(gruppe.map { abs($0.einzelpreis - median) })

            for p in gruppe {
                let faktor = p.einzelpreis / median

                // 1) Zehnerpotenz/Komma-Falle — die spezifischste (und teuerste) Diagnose zuerst.
                if let stufe = zehnerpotenz(faktor) {
                    befunde.append(PreisBefund(
                        punktID: p.id, bezeichnung: p.bezeichnung, art: .zehnerpotenz,
                        einzelpreis: p.einzelpreis, referenz: median, faktor: faktor,
                        hinweis: "EP ist rund \(stufe) vom Mittel gleichartiger Positionen — "
                               + "sieht nach verrutschtem Komma / Zehnerpotenz aus (z. B. 8,02 statt 80,21). Prüfen."))
                    continue
                }

                // 2) Robuster Ausreißer (nur wenn es überhaupt eine Streuung gibt).
                if mad > 0 {
                    let robusterZ = abs(p.einzelpreis - median) / (1.4826 * mad)
                    if robusterZ >= madSchwelle {
                        befunde.append(PreisBefund(
                            punktID: p.id, bezeichnung: p.bezeichnung, art: .ausreisser,
                            einzelpreis: p.einzelpreis, referenz: median, faktor: faktor,
                            hinweis: "EP fällt deutlich aus dem Rahmen der gleichartigen Positionen "
                                   + "(Faktor \(String(format: "%.1f", faktor))×). Menge/Einheit/Zahl prüfen."))
                    }
                }
            }
        }
        // Die auffälligsten zuerst (am weitesten vom Mittel).
        return befunde.sorted { abs(log10(max($0.faktor, 1e-6))) > abs(log10(max($1.faktor, 1e-6))) }
    }

    // MARK: - Intern

    /// Einheiten vergleichbar machen: „m²" == „m2" == „M2 ", Leerraum weg.
    static func normEinheit(_ e: String) -> String {
        e.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
    }

    private static func medianOf(_ werte: [Double]) -> Double {
        let s = werte.sorted()
        guard !s.isEmpty else { return 0 }
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Erkennt ~×100, ×10, /10, /100 (verrutschtes Komma / Zehnerpotenz). nil = unauffällig.
    private static func zehnerpotenz(_ faktor: Double) -> String? {
        let stufen: [(mitte: Double, label: String)] =
            [(100, "100×"), (10, "10×"), (0.1, "1/10"), (0.01, "1/100")]
        for s in stufen where faktor >= s.mitte * 0.7 && faktor <= s.mitte * 1.4 {
            return s.label
        }
        return nil
    }
}
