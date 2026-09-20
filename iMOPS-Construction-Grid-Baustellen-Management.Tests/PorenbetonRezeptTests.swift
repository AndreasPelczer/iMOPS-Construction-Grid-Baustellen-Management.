//
//  PorenbetonRezeptTests.swift
//  Der erste gekochte Gang: Porenbeton-Mauerwerk (Ytong/Hebel).
//
//  Vorher fand der Katalog für eine 24-cm-Ytong-Außenwand GAR NICHTS, und für die
//  tragende 17,5er-Innenwand ausgerechnet „Innenwände nicht tragend Kalksandstein/
//  Porenbeton" — also das falsche Rezept. Genau die Art stiller Fehler, die eine
//  Kalkulation unbrauchbar macht, ohne dass jemand es merkt.
//
//  Diese Tests halten fest, dass MAU-007 die echten Bezeichnungen einer laufenden
//  Baustelle einfängt und dabei nichts Fremdes mitnimmt.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct PorenbetonRezeptTests {

    private var katalog: STLBKatalog { STLBKatalog.shared }

    /// Bezeichnungen, wie sie aus einem SketchUp-Modell und der Statik kommen —
    /// nicht wie sie im Katalog stehen. Genau das ist der Prüffall.
    private let wandpositionen = [
        "Mauerwerk Außenwand Ytong PPW 2-0,35, d = 24 cm, Dünnbettmörtel, EG",
        "Mauerwerk Außenwand Ytong PP 2-0,35, d = 24 cm, OG",
        "Mauerwerk Innenwand tragend Ytong PP 4-0,50, d = 17,5 cm, EG",
        "Mauerwerk Innenwand Ytong PP 4-0,55, d = 11,5 cm, EG",
        "Giebelmauerwerk herstellen",
    ]

    @Test func jedeWandpositionFindetDasPorenbetonRezept() {
        for text in wandpositionen {
            let b = katalog.finde(leistung: text)
            #expect(b != nil, "kein Baustein fuer: \(text)")
            #expect(b?.id == "MAU-007", "falscher Baustein fuer \(text): \(b?.id ?? "-")")
        }
    }

    @Test func dasRezeptHaengtAmVorhandenenAufwandswert() throws {
        let b = try #require(katalog.finde(leistung: wandpositionen[0]))
        let key = try #require(b.aufwandswertKey)
        #expect(key == "mauerarbeiten.mauerwerk_porenbeton")
        let t = try #require(AufwandswerteKatalog.shared.eintrag(key: key))
        #expect(t.mittel > 0)
        #expect(t.einheit == "m2")
    }

    /// Der Aufwandswert steht je m², die Positionen rechnen in m³. Die Brücke ist die
    /// Wanddicke aus dem Positionstext — ohne sie wäre der Lohn um Faktor 4 daneben.
    @Test func einheitenbrueckeRechnetM2AufM3() throws {
        let b = try #require(katalog.finde(leistung: wandpositionen[0]))
        let t = try #require(AufwandswerteKatalog.shared.eintrag(key: b.aufwandswertKey ?? ""))
        let bruecke = MopsUmrechner.Bruecke(dicke: 0.24)
        let um = try #require(MopsUmrechner.umrechnung(von: t.einheit, nach: "m³", bruecke: bruecke))
        // 0,5 h/m² bei 24 cm Wand → rund 2,1 h/m³
        let stundenProM3 = t.mittel * um.proFaktor
        #expect(abs(stundenProM3 - t.mittel / 0.24) < 0.001)
        #expect(stundenProM3 > t.mittel)
    }

    /// Kein Rezept ohne Grundlage: der Materialpreis steht bewusst auf 0, weil er
    /// Betriebswissen ist und aus den Stammdaten kommt. Der Katalog darf ihn nicht raten.
    @Test func materialpreisBleibtOffen() throws {
        let b = try #require(katalog.finde(leistung: wandpositionen[0]))
        let m = try #require(b.material)
        #expect(m.richtpreis == 0)
        #expect(m.text.lowercased().contains("porenbeton"))
    }

    @Test func aussparungenLandenNichtImMauerwerksRezept() throws {
        let b = try #require(katalog.finde(leistung:
            "Aussparungen und Wanddurchbrüche im Mauerwerk herstellen"))
        #expect(b.id == "MAU-008")
    }

    /// Gegenprobe: ein Poroton- oder Kalksandstein-Text darf NICHT beim Porenbeton landen.
    @Test func andereSteineBleibenBeiIhremRezept() {
        #expect(katalog.finde(leistung: "Außenwandmauerwerk Poroton-Planziegel d = 36,5 cm")?.id == "MAU-001")
        #expect(katalog.finde(leistung: "Innenwände tragend Kalksandstein d = 17,5 cm")?.id == "MAU-002")
    }
}
