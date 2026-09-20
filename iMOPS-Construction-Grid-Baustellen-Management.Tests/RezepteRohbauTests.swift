//
//  RezepteRohbauTests.swift
//  Die gekochten Rezepte, an echten Positionsbezeichnungen einer laufenden Baustelle
//  geprüft — nicht an Katalogtexten. Genau da lag der Fehler: der Katalog kannte die
//  Leistung, fand sie aber nie, weil niemand so schreibt wie der Katalog.
//
//  Grundregel dieser Runde: KEINE erfundene Zahl. Jeder Baustein hängt an einem
//  Aufwandswert, der schon belegt im Repo steht. Die einzige neue Zahl
//  (betonarbeiten.elementdecke_verlegen) ist aus zwei vorhandenen abgeleitet und der
//  Rechenweg steht in der YAML — dieser Test rechnet ihn nach.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct RezepteRohbauTests {

    private var katalog: STLBKatalog { STLBKatalog.shared }
    private var werte: AufwandswerteKatalog { AufwandswerteKatalog.shared }

    /// Positionstext, wie er aus Modell/Statik/Planauswertung kommt → erwarteter Baustein.
    private let zuordnung: [(text: String, code: String)] = [
        ("Filigran-Elementdecke d = 20 cm, C 20/25, liefern und verlegen", "BET-012"),
        ("Ortbetonergänzung Decke C 20/25",                                "BET-013"),
        ("Geländemodellierung Hanglage (Cut/Fill), rd. 7 m Gefälle",       "ERD-014"),
        ("Böschung herstellen, max. 1:1,5 (B-Plan)",                       "ERD-015"),
        ("Retentionszisterne 5.000 l mit Überlauf setzen und anschliessen","KAN-015"),
        ("XPS-50-Dämmeinlagen unterseitig im Bereich der Wandöffnungen",   "ABD-010"),
        ("Bauwerksabdichtung W1.1-E, +15 cm ü. Gelände, Spritzwasser +30 cm", "ABD-002"),
        ("Beton Fundamentbett unter Stützwinkel C25/30",                   "BET-009"),
        ("Grundleitungen KG DN 100 frostfrei, Gefälle 1,5-2,5 %",          "KAN-006"),
        ("Stellplätze befestigen (2 Stück lt. B-Plan)",                    "PFL-002"),
        ("Deckendurchbrueche und Bodendurchbrueche aussparen",             "MAU-008"),
    ]

    @Test func jedePositionFindetIhrRezept() {
        for (text, code) in zuordnung {
            let b = katalog.finde(leistung: text)
            #expect(b != nil, "kein Baustein fuer: \(text)")
            #expect(b?.id == code, "\(text) -> \(b?.id ?? "nichts"), erwartet \(code)")
        }
    }

    /// Kein Baustein ohne auflösbaren Aufwandswert — sonst rechnet der Mops nichts,
    /// obwohl er einen Treffer meldet.
    @Test func jederNeueBausteinHatEinenAufloesbarenAufwandswert() throws {
        for code in ["BET-012", "BET-013", "ERD-014", "ERD-015", "KAN-015", "ABD-010",
                     "MAU-007", "MAU-008"] {
            let b = try #require(katalog.alle().first { $0.id == code }, "Baustein \(code) fehlt")
            let key = try #require(b.aufwandswertKey, "\(code) ohne aufwandswert_key")
            let t = try #require(werte.eintrag(key: key), "\(code): Key \(key) nicht auflösbar")
            #expect(t.mittel > 0, "\(code): Aufwandswert 0")
        }
    }

    /// Die einzige neue Zahl dieser Runde, nachgerechnet:
    /// Elementdecke = Ortbetondecke minus Deckenschalung.
    @Test func derAbgeleiteteWertStimmtMitSeinerHerleitung() throws {
        let decke     = try #require(werte.eintrag(key: "betonarbeiten.stahlbeton_decke"))
        let schalung  = try #require(werte.eintrag(key: "schalarbeiten.schalung_decke"))
        let element   = try #require(werte.eintrag(key: "betonarbeiten.elementdecke_verlegen"))
        let hergeleitet = decke.mittel - schalung.mittel
        #expect(abs(element.mittel - hergeleitet) < 0.0001,
                "hergeleitet \(hergeleitet), in der YAML steht \(element.mittel)")
        #expect(element.einheit == "m2")
    }

    /// Gegenprobe: die neuen Bausteine dürfen fremde Positionen nicht einfangen.
    @Test func neueBausteineGreifenNichtDaneben() {
        let fremd: [(String, String)] = [
            ("Beton Bodenplatte C25/30 XC2, d = 16 cm", "BET-012"),
            ("Baugrube Wohnhaus ausheben, BKL 4-6",     "ERD-015"),
            ("Pflaster 160/160/80 Fahrwege verlegen",   "KAN-015"),
        ]
        for (text, darfNicht) in fremd {
            #expect(katalog.finde(leistung: text)?.id != darfNicht,
                    "\(text) landet faelschlich bei \(darfNicht)")
        }
    }

    /// Was bewusst OHNE Rezept bleibt: lieber eine ehrliche Lücke als ein geratener Wert.
    /// Dieser Test hält den Stand fest — schlägt er an, hat jemand eine Zahl ohne
    /// Herkunft nachgeschoben oder eine Lücke sauber geschlossen. Beides will man sehen.
    @Test func bewussteLueckenBleibenLeer() {
        let ohneBeleg = [
            "Kimmschicht LM 21 (MG III) unter Außenwand",
            "Fundamenterder umlaufend einbauen, Anschlussfahne im HWR/HAR",
            "Plattendruckversuche Ev2 (Polsternachweis)",
        ]
        for text in ohneBeleg {
            #expect(katalog.finde(leistung: text) == nil,
                    "\(text) hat jetzt ein Rezept - Quelle pruefen und diesen Test anpassen")
        }
    }
}
