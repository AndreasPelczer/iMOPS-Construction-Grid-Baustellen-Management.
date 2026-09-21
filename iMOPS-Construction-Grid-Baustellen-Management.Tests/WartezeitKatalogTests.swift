//
//  WartezeitKatalogTests.swift
//
//  "erst hat man den bagger gesehen dann ?? dann zeit.. es ging um trockenzeit oder
//   so, das habe ich sofort verstanden" (Andreas, 21.09.2026, über die Ablaufplan-Skizze)
//
//  🔴 Gemessen in der echten Datenbank: `Bauablauf` rechnet Wartezeiten seit jeher
//  mit — aber ALLE 598 Voraussetzungs-Kanten standen auf 0. Die Rechnung konnte es,
//  eingetragen hat sie nie jemand. Beton härtet trotzdem.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct WartezeitKatalogTests {

    @Test func derKatalogLaedt() {
        #expect(!WartezeitKatalog.alle.isEmpty, "wartezeiten.yaml muss im Bundle liegen")
    }

    @Test func betonHaertenWirdErkannt() throws {
        let w = try #require(WartezeitKatalog.vorschlag(nach: "331 Beton härten Decke OG"))
        #expect(w.tage == 3)
        #expect(w.bezeichnung.contains("Beton"))
    }

    /// 🔴 Der längste Treffer gewinnt: „Estrich belegreif" (28 T) schlägt
    /// „estrich begehbar" (3 T) — beides steht im Katalog, und der Unterschied
    /// sind vier Wochen Bauzeit.
    @Test func derGenauereTrefferGewinnt() throws {
        let begehbar = try #require(WartezeitKatalog.vorschlag(nach: "Estrich begehbar machen"))
        let belegreif = try #require(WartezeitKatalog.vorschlag(nach: "Estrich trocknen bis belegreif"))
        #expect(begehbar.tage == 3)
        #expect(belegreif.tage == 28)
    }

    /// Lange Liegezeiten dürfen nie still gesetzt werden.
    @Test func langeZeitenBrauchenRueckfrage() throws {
        let estrich = try #require(WartezeitKatalog.vorschlag(nach: "Estrich trocknen"))
        #expect(estrich.brauchtRueckfrage, "28 Tage verschieben einen Termin um einen Monat")

        let mauerwerk = try #require(WartezeitKatalog.vorschlag(nach: "Mauerwerk aushärten"))
        #expect(!mauerwerk.brauchtRueckfrage, "1 Tag darf durchlaufen")
    }

    /// Gewöhnliche Arbeit bekommt keine Liegezeit angehängt.
    @Test func ohneTrefferKeinVorschlag() {
        for arbeit in ["312 Baugrube / Erdbau", "Pfosten setzen", "Bewehrung einlegen",
                       "572 Außenanlagen und Freiflächen"] {
            #expect(WartezeitKatalog.vorschlag(nach: arbeit) == nil,
                    "\(arbeit) braucht keine Liegezeit")
        }
    }

    /// Jeder Eintrag trägt seinen Hinweis und seine Quelle — ein Wert ohne Herkunft
    /// ist eine Behauptung.
    @Test func jederEintragIstBelegt() {
        for w in WartezeitKatalog.alle {
            #expect(!w.hinweis.isEmpty, "\(w.id) ohne Hinweis")
            #expect(!w.quelleKurz.isEmpty, "\(w.id) ohne Quelle")
            #expect(w.tage > 0, "\(w.id) ohne Tage")
        }
    }

    /// Der Vorgänger bestimmt die Liegezeit: was ER hinterlässt, muss trocknen.
    @Test func derVorgaengerBestimmt() throws {
        let w = try #require(WartezeitKatalog.vorschlag(von: "331 Beton härten Decke",
                                                        zu: "341 Mauerwerk OG"))
        #expect(w.tage == 3, "die Decke härtet, nicht das Mauerwerk darüber")
    }
}
