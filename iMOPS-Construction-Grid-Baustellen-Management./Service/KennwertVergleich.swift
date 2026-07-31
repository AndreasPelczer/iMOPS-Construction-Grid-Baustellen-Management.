import Foundation
import CoreData

// MARK: - KennwertVergleich
//
// Stellt das kalkulierte LV der Grobkostenschaetzung aus dem Planer gegenueber —
// aber NUR fuer die Gewerke, die das LV ueberhaupt abdeckt.
//
// Warum das der Punkt ist: die Planer-Schaetzung rechnet das GANZE Haus
// (Wohnflaeche x Kennwert, verteilt auf alle Gewerke inkl. Sanitaer, Heizung, Maler).
// Ein LV deckt meist nur die eigene Leistung ab. Beide Summen nebeneinander zu
// stellen — 386 T€ gegen 112 T€ — legt einen Vergleich nahe, den es nicht gibt und
// liest sich wie „274 T€ unter Plan". Hier wird darum die Schaetzung auf die
// Kostengruppen heruntergerechnet, die im LV wirklich vorkommen.
//
// ⚠️ ZUR AUSSAGEKRAFT: Der Kennwert (€/m²) ist ein FIRMENWERT aus den Einstellungen,
// kein lizenzierter BKI-Wert (siehe FirmenSettings). Die prozentuale Verteilung auf
// die Gewerke kommt aus `HouseProjectGenerator` und ist ebenfalls eine Faustformel.
// Das Ergebnis ist eine Plausibilitaetsfrage („liege ich in der Groessenordnung?"),
// kein Urteil. Buch Kap 6: geschaetzt ist ein anderer Zustand als gemessen.
enum KennwertVergleich {

    /// Ein Gewerke-Topf der Schaetzung, gegen die passende LV-Summe gestellt.
    struct Zeile: Identifiable {
        let topf: String
        let soll: Double        // aus der Grobkostenschaetzung
        let ist: Double         // aus dem kalkulierten LV
        var id: String { topf }

        var abweichung: Double { ist - soll }
        /// Relative Abweichung; nil wenn der Soll-Wert 0 ist (dann sagt % nichts).
        var abweichungProzent: Double? {
            soll > 0 ? (ist - soll) / soll : nil
        }
    }

    struct Ergebnis {
        let zeilen: [Zeile]
        let wohnflaeche: Double
        let kennwertJeQm: Double
        let ausstattung: String
        /// Gewerke, die die Schaetzung kennt, das LV aber nicht abdeckt — bewusst
        /// NICHT mitgerechnet, aber benannt, damit die Luecke sichtbar bleibt.
        let nichtAbgedeckt: [String]

        var sollGesamt: Double { zeilen.reduce(0) { $0 + $1.soll } }
        var istGesamt:  Double { zeilen.reduce(0) { $0 + $1.ist } }
        var abweichung: Double { istGesamt - sollGesamt }
        var abweichungProzent: Double? {
            sollGesamt > 0 ? (istGesamt - sollGesamt) / sollGesamt : nil
        }
    }

    // MARK: - Zuordnung Kostengruppe -> Gewerke-Topf
    //
    // Die Schaetzung denkt in Gewerken, das LV in DIN-276-Kostengruppen. Diese
    // Zuordnung ist eine bewusste Vereinfachung und die Stelle, an der man streiten
    // kann — deshalb steht sie hier an EINER Stelle und nicht verteilt im Code.
    //
    // KG 334/344 (Fenster, Tueren) sind absichtlich aus dem Rohbau herausgezogen:
    // in der Schaetzung sind sie ein eigener Topf, im LV stecken sie unter 330/340.
    static func topf(fuerKostengruppe kg: String) -> String? {
        guard let erste = kg.first else { return nil }

        // Fenster/Tueren zuerst — sonst wuerden sie unter 330/340 als Rohbau landen.
        if kg.hasPrefix("334") || kg.hasPrefix("344") { return "Fenster & Türen" }

        switch erste {
        case "3":
            if kg.hasPrefix("360") { return "Dach" }
            return "Rohbau"                       // 310-350, 370-390
        case "4":
            if kg.hasPrefix("41") { return "Sanitär" }
            if kg.hasPrefix("42") || kg.hasPrefix("43") { return "Heizung" }
            return "Elektro"                      // 440-490
        case "5":
            return "Außenanlagen"
        default:
            return nil                            // 100/200/600/700 = nicht Bauleistung
        }
    }

    /// Die Schaetzungs-Toepfe in derselben Sprache wie `topf(fuerKostengruppe:)`.
    private static func schaetzungNachTopf(_ k: Kostenaufstellung) -> [String: Double] {
        [
            "Rohbau":         k.rohbau,
            "Dach":           k.dach,
            "Fenster & Türen": k.fensterTueren,
            "Elektro":        k.elektro,
            "Sanitär":        k.sanitaer,
            "Heizung":        k.heizung,
            "Trockenbau":     k.trockenbau,
            "Estrich":        k.estrich,
            "Maler":          k.maler,
            "Außenanlagen":   k.aussenanlagen
        ]
    }

    // MARK: - Rechnen

    /// Vergleicht das LV eines Events mit der dort hinterlegten Grobkostenschaetzung.
    /// `nil`, wenn im Planer noch nichts konfiguriert wurde — dann gibt es nichts zu
    /// vergleichen, und die Oberflaeche soll das auch so sagen statt 0 anzuzeigen.
    @MainActor
    static func berechne(fuer event: Event) -> Ergebnis? {
        let extras = EventExtrasPayload.laden(aus: event)
        guard let projekt = extras.houseProject else { return nil }

        let schaetzung = HouseProjectGenerator.generate(from: projekt).baukosten
        let sollJeTopf = schaetzungNachTopf(schaetzung)

        // Ist-Summen je Topf aus dem LV. Nur zaehlbare Positionen — ein Deckel zaehlt,
        // seine Belege nicht (REB-23.003), sonst waere alles doppelt drin.
        let positionen = ((event.lvPositionen as? Set<LVPosition>) ?? []).sorted {
            ($0.posNr ?? "") < ($1.posNr ?? "")
        }
        var istJeTopf: [String: Double] = [:]
        for pos in positionen.zaehlbarePositionen() {
            guard let kg = pos.kostenGruppeNummer, let t = topf(fuerKostengruppe: kg) else { continue }
            istJeTopf[t, default: 0] += LVKalkulator.effektiverEP(for: pos) * pos.menge
        }

        // Verglichen wird nur, was das LV abdeckt. Alles andere waere ein Vergleich
        // gegen eine Leistung, die gar nicht angeboten wurde.
        let zeilen = sollJeTopf
            .filter { istJeTopf[$0.key] != nil }
            .map { Zeile(topf: $0.key, soll: $0.value, ist: istJeTopf[$0.key] ?? 0) }
            .sorted { $0.soll > $1.soll }

        let nichtAbgedeckt = sollJeTopf
            .filter { istJeTopf[$0.key] == nil && $0.value > 0 }
            .keys
            .sorted()

        return Ergebnis(zeilen: zeilen,
                        wohnflaeche: projekt.wohnflaeche,
                        kennwertJeQm: projekt.ausstattung.kostenProQm,
                        ausstattung: projekt.ausstattung.rawValue,
                        nichtAbgedeckt: Array(nichtAbgedeckt))
    }
}
