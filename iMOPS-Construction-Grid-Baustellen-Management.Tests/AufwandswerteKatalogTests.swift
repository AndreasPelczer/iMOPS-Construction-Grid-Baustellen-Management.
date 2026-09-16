//
//  AufwandswerteKatalogTests.swift
//  Die lokale Richtwert-Tabelle: findet sie zur LV-Leistung den richtigen Eintrag —
//  mit der richtigen Kolonne (echte Rollen statt generisch "Maurer/Helfer")?
//  Ehrlich: kein Treffer → nil (kein erfundener Wert).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AufwandswerteKatalogTests {

    @Test func yamlLaedtEintraege() async {
        let n = AufwandswerteKatalog.shared.eintragCount()
        // 89 Aufwands-Einträge über 20 Gewerke (Stand YAML 1.0.0).
        #expect(n >= 80)
    }

    /// Der Nordstern-Fall: "Rohrgraben herstellen DN 400" → graben_ausheben,
    /// 0,30 h/m mittel, Kolonne "Baggerfahrer + Helfer" (NICHT Maurer).
    @Test func rohrgrabenTrifftGrabenAusheben() async {
        let t = AufwandswerteKatalog.shared.finde(
            leistung: "Rohrgraben herstellen DN 400",
            langtext: "Rohrgraben ausheben, Tiefe ca. 2,50 m, einschl. Verbau, Boden Kl. 3-4.")
        #expect(t != nil)
        #expect(t?.key == "graben_ausheben")
        #expect(t?.mittel == 0.30)
        #expect(t?.einheit == "m")
        #expect(t?.kolonne.contains("Baggerfahrer") == true)
        #expect(t?.kolonne.lowercased().contains("maurer") == false)
    }

    /// Kanalrohr verlegen → eigener Eintrag, andere Kolonne (Rohrleger).
    @Test func kanalrohrTrifftVerlegen() async {
        let t = AufwandswerteKatalog.shared.finde(leistung: "Kanalrohr verlegen DN 300", langtext: nil)
        #expect(t?.key == "kanalrohr_verlegen")
        #expect(t?.kolonne.contains("Rohrleger") == true)
    }

    /// Mauerwerk trifft ein Mauer-Gewerk (Maurer ist hier RICHTIG).
    @Test func mauerwerkTrifftMaurer() async {
        let t = AufwandswerteKatalog.shared.finde(leistung: "Poroton-Mauerwerk 36,5 cm herstellen", langtext: nil)
        #expect(t?.gewerk == "mauerarbeiten")
        #expect(t?.kolonne.contains("Maurer") == true)
    }

    /// Plural/Umlaut: „Straßenabläufe" trifft den Singular-Eintrag `strassenablauf`.
    @Test func pluralTrifftSingular() async {
        #expect(AufwandswerteKatalog.shared.finde(leistung: "Straßenabläufe setzen")?.key == "strassenablauf")
        #expect(AufwandswerteKatalog.shared.finde(leistung: "Stürze über Öffnungen")?.key == "sturz_einbauen")
    }

    /// Synonym: „Steinzeugrohr" ist ein Kanalrohr → kanalrohr_verlegen (Rohrleger).
    @Test func synonymSteinzeugIstKanalrohr() async {
        let t = AufwandswerteKatalog.shared.finde(leistung: "Steinzeugrohr DN 400 verlegen")
        #expect(t?.key == "kanalrohr_verlegen")
        #expect(t?.kolonne.contains("Rohrleger") == true)
    }

    /// Gewerks-Guard: „Mauerwerk Innenwände tragend" bleibt Maurer, wird NICHT zum Maler.
    /// Das generische „Innenwände" darf das definierende „Mauerwerk" nicht überstimmen.
    @Test func mauerwerkWirdNichtZumMaler() async {
        let t = AufwandswerteKatalog.shared.finde(leistung: "Mauerwerk Innenwände tragend")
        #expect(t?.gewerk == "mauerarbeiten")
        #expect(t?.kolonne.lowercased().contains("maurer") == true)
    }

    /// Kein plausibler Treffer → nil (kein erfundener Wert, Prof übernimmt).
    @Test func unbekanntesGibtNil() async {
        let t = AufwandswerteKatalog.shared.finde(leistung: "Spezialanfertigung Sonderposten XYZ", langtext: nil)
        #expect(t == nil)
    }
}
