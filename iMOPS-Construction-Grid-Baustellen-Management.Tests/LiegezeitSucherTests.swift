//
//  LiegezeitSucherTests.swift
//
//  "wir brauchen immer eine dokumentierte und belegte zahl für die wartezeit, die
//   kann aus folgenden quellen kommen, dokument, fundus, internet.. Wenn eine
//   auswahl besteht entscheidet der mensch?" (Andreas, Nacht 21./22.09.2026)
//   — und auf Rückfrage: "ok, ohne internet."
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LiegezeitSucherTests {

    private func kandidat(_ tage: Double, _ h: LiegezeitHerkunft) -> LiegezeitKandidat {
        LiegezeitKandidat(tage: tage, herkunft: h, quelle: "Test")
    }

    // MARK: Rangfolge

    /// 🔴 Die Reihenfolge ist keine Geschmacksfrage: je näher an DIESER Baustelle,
    /// desto weiter vorn. Das Datenblatt des gelieferten Materials schlägt alles.
    @Test func dieRangfolgeStimmt() {
        #expect(kandidat(1, .datenblatt).rang < kandidat(1, .statiker).rang)
        #expect(kandidat(1, .statiker).rang  < kandidat(1, .erfahrung).rang)
        #expect(kandidat(1, .erfahrung).rang < kandidat(1, .katalog).rang)
    }

    @Test func derKatalogStehtHinten() async {
        let e = await LiegezeitSucher.suche(nach: "Beton härten Decke", event: nil)
        #expect(e.kandidaten.count == 1, "ohne Baustelle bleibt nur der Richtwert")
        #expect(e.kandidaten.first?.herkunft == .katalog)
    }

    @Test func ohneTrefferGarKeinKandidat() async {
        let e = await LiegezeitSucher.suche(nach: "Pfosten setzen", event: nil)
        #expect(e.kandidaten.isEmpty)
        #expect(e.satz == "Keine belegte Zahl gefunden.")
    }

    // MARK: 🔴 Widerspruch

    /// Der wichtigste Test: sagen zwei Quellen Verschiedenes, muss das DASTEHEN.
    /// Heimlich die erste zu nehmen wäre wieder „er wusste es und sagte nichts".
    @Test func widerspruchWirdGenannt() {
        var e = LiegezeitSucher.Ergebnis()
        e.kandidaten = [kandidat(2, .datenblatt), kandidat(3, .katalog)]
        #expect(e.widersprechenSich)
        #expect(e.satz.contains("nicht einig"))
        #expect(e.satz.contains("Du entscheidest"))
    }

    /// Ein halber Tag Unterschied ist dieselbe Aussage, kein Widerspruch.
    @Test func kleineAbweichungIstKeinWiderspruch() {
        var e = LiegezeitSucher.Ergebnis()
        e.kandidaten = [kandidat(3, .datenblatt), kandidat(3.5, .katalog)]
        #expect(!e.widersprechenSich)
        #expect(e.satz.contains("alle einig"))
    }

    @Test func eineQuelleWidersprichtSichNicht() {
        var e = LiegezeitSucher.Ergebnis()
        e.kandidaten = [kandidat(3, .katalog)]
        #expect(!e.widersprechenSich)
    }

    // MARK: Der Fundus

    /// Die Frage verlangt Zahl UND Quelle — eine Zahl ohne Herkunft wäre nur eine
    /// weitere Behauptung.
    @Test func dieFrageVerlangtEineQuelle() {
        let f = LiegezeitSucher.fundusFrage(arbeit: "Beton härten")
        #expect(f.contains("TAGE:"))
        #expect(f.contains("QUELLE:"))
        #expect(f.contains("unbekannt"), "er muss auch sagen duerfen: weiss ich nicht")
    }

    @Test func antwortWirdGelesen() throws {
        let k = try #require(LiegezeitSucher.kandidatAus("TAGE: 3\nQUELLE: DIN 1045-3, Tabelle 2"))
        #expect(k.tage == 3)
        #expect(k.quelle.contains("DIN 1045-3"))
        #expect(k.herkunft == .erfahrung, "der Fundus ist kein Beleg, nur ein Kandidat")
    }

    @Test func kommaZahlenGehenAuch() throws {
        let k = try #require(LiegezeitSucher.kandidatAus("TAGE: 1,5\nQUELLE: Merkblatt"))
        #expect(k.tage == 1.5)
    }

    /// 🔴 Lieber kein Kandidat als ein aus Prosa geratener.
    @Test func prosaWirdVerworfen() {
        #expect(LiegezeitSucher.kandidatAus("TAGE: unbekannt") == nil)
        #expect(LiegezeitSucher.kandidatAus("Das kommt ganz darauf an, meist 3 Tage.") == nil)
        #expect(LiegezeitSucher.kandidatAus("") == nil)
        #expect(LiegezeitSucher.kandidatAus("TAGE: 0\nQUELLE: x") == nil)
    }

    // MARK: Dokumente

    /// Nur Felder, die die Sache benennen — nicht jede Zahl im Dokument.
    @Test func nurBenannteFelderZaehlen() {
        let gut = JSONValue.object(["trocknungszeit_tage": .number(28)])
        #expect(LiegezeitSucher.tageAusFeldern(gut) == 28)

        let text = JSONValue.object(["wartezeit_tage": .string("1,5")])
        #expect(LiegezeitSucher.tageAusFeldern(text) == 1.5)

        let falsch = JSONValue.object(["menge": .number(28), "preis": .number(3)])
        #expect(LiegezeitSucher.tageAusFeldern(falsch) == nil)
        #expect(LiegezeitSucher.tageAusFeldern(nil) == nil)
    }
}
