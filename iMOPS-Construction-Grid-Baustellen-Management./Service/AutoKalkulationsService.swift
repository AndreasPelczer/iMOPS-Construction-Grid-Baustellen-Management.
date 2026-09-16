import Foundation
import CoreData

// MARK: - AutoKalkulationsService  („Mops fass")
//
// Orchestriert die automatische Bepreisung eines importierten GAEB-LV.
//
// KEIN neuer Motor: die Kette existiert schon. Dieser Service RUFT sie über das ganze LV
//   1. `LeistungskatalogService.autoMatch(position:in:)` — findet das gelernte Rezept und
//      schreibt Lohn (+ Material/Gerät) auf die Position; Treffer=true, sonst false.
//   2. `LVKalkulator.kalkuliere(position:)` — rechnet daraus den Einheitspreis.
// und DIAGNOSTIZIERT, was zum vollständigen Preis noch fehlt.
//
// Das Mops-Protokoll: Kein Preis ohne Grundlage. Lieber eine ehrliche Lücke (ROT) als eine
// erfundene Zahl. Der Mops schätzt nichts von selbst — GELB heißt „Rezept da, aber ein Wert
// fehlt" (Aufwandswert/Material), zu füllen über die vorhandene Schätzung/Stammdaten.
enum AutoKalkulationsService {

    enum Status: String { case gruen, gelb, rot }

    struct Ergebnis: Identifiable {
        let id = UUID()
        let position: LVPosition
        let status: Status
        let meldungen: [String]
        let einheitspreisVK: Double
    }

    /// Bilanz für die Ampel-Karte oben in der Review.
    struct Bilanz {
        let gruen: Int
        let gelb: Int
        let rot: Int
        var gesamt: Int { gruen + gelb + rot }
        /// Export erst erlaubt, wenn keine Position mehr ROT ist (Vier-Augen bleibt separat).
        var exportBereit: Bool { rot == 0 && gesamt > 0 }
    }

    static func bilanz(_ ergebnisse: [Ergebnis]) -> Bilanz {
        Bilanz(
            gruen: ergebnisse.filter { $0.status == .gruen }.count,
            gelb: ergebnisse.filter { $0.status == .gelb }.count,
            rot: ergebnisse.filter { $0.status == .rot }.count)
    }

    /// „Mops fass": über alle Positionen matchen + rechnen + diagnostizieren.
    /// Achtung: verändert die Positionen (schreibt das Rezept auf Treffer) — genau das ist
    /// das Ausfüllen. Gedacht direkt nach dem Import (leere Positionen).
    @discardableResult
    static func fass(positionen: [LVPosition], in ctx: NSManagedObjectContext) -> [Ergebnis] {
        positionen.map { bewerte($0, in: ctx) }
    }

    /// Eine Position bewerten. Reine Ableitung aus dem echten Modell — keine Schätzung.
    static func bewerte(_ pos: LVPosition, in ctx: NSManagedObjectContext) -> Ergebnis {
        let bez = (pos.bezeichnung ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let einheit = (pos.einheit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Rezept-Treffer? (schreibt bei Treffer Lohn/Material/Gerät auf die Position)
        guard LeistungskatalogService.autoMatch(position: pos, in: ctx) else {
            // Kein gelerntes Rezept — aber vielleicht ein Richtwert im Aufwandswerte-Katalog?
            // Findet er einen, wird die Zeit als GELB-Schätzung geschrieben (echte Kolonne + Quelle),
            // statt die Position blind auf ROT zu lassen.
            if let t = AufwandswerteKatalog.shared.finde(leistung: bez, langtext: pos.langtext) {
                LeistungskatalogService.schreibeAufwandAlsLohn(maurer: t.mittel, helfer: 0, auf: pos, in: ctx)
                let kalk = LVKalkulator.kalkuliere(position: pos)
                let g = String(format: "%g", t.mittel), lo = String(format: "%g", t.min), hi = String(format: "%g", t.max)
                let msg = "🟡 Richtwert \(g) h/\(t.einheit) (Spanne \(lo)–\(hi)) · Mannschaft: "
                        + "\(t.kolonne.isEmpty ? "—" : t.kolonne) · Quelle \(t.quelleKurz). "
                        + "Schätzung — Rollen/Preis prüfen; Material fehlt noch."
                return Ergebnis(position: pos, status: .gelb, meldungen: [msg],
                                einheitspreisVK: kalk.einheitspreisVK)
            }
            return Ergebnis(
                position: pos, status: .rot,
                meldungen: ["Kein gelerntes Rezept und kein Richtwert für „\(bez)“ (\(einheit.isEmpty ? "?" : einheit)). "
                          + "Aus dem Katalog wählen, eine Aufwandswert-Schätzung übernehmen oder Stammdaten ergänzen."],
                einheitspreisVK: 0)
        }

        // 2) Aus dem Rezept rechnen und auf Vollständigkeit prüfen.
        let kalk = LVKalkulator.kalkuliere(position: pos)
        var meldungen: [String] = []

        // Material im Rezept, aber ohne Stammdaten-Preis?
        let unbepreist = pos.materialArray.filter {
            ($0.materialName?.isEmpty == false) && $0.einzelpreis <= 0
        }
        for m in unbepreist {
            meldungen.append("Kein Materialpreis für „\(m.materialName ?? "")“ — in Stammdaten ergänzen.")
        }

        // Kein Preis herausgekommen → der Aufwandswert (Lohn) fehlt meist.
        if kalk.einheitspreisVK <= 0 {
            if kalk.lohnKosten <= 0 {
                meldungen.append("Kein Aufwandswert (Lohn) hinterlegt — Prof/KI-Schätzung übernehmen oder Erfahrungswert eintragen.")
            }
            return Ergebnis(position: pos, status: .gelb,
                            meldungen: meldungen.isEmpty ? ["Rezept unvollständig — Preis 0. Bitte prüfen."] : meldungen,
                            einheitspreisVK: kalk.einheitspreisVK)
        }

        // Preis da, aber Material-Lücke → GELB (bepreist, aber noch nicht sauber).
        if !unbepreist.isEmpty {
            return Ergebnis(position: pos, status: .gelb, meldungen: meldungen,
                            einheitspreisVK: kalk.einheitspreisVK)
        }

        // Vollständig gerechnet → GRÜN, mit transparenter Quelle.
        let quelle = "Kalkuliert: \(euro(kalk.einheitspreisVK))/\(einheit) "
                   + "(Lohn \(euro(kalk.lohnKosten)) · Material \(euro(kalk.materialKosten)) · Gerät \(euro(kalk.geraeteKosten)))"
        return Ergebnis(position: pos, status: .gruen, meldungen: [quelle],
                        einheitspreisVK: kalk.einheitspreisVK)
    }

    private static func euro(_ d: Double) -> String { String(format: "%.2f €", d) }
}
