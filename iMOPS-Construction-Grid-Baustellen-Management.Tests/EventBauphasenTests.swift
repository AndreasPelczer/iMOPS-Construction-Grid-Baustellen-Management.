//
//  EventBauphasenTests.swift
//  Bogen 3: der Ablauf-Mapper. Reihenfolge aus dem Rang, Dauer aus Manntagen, parallel je Rang.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct EventBauphasenTests {

    private func vorgang(_ name: String, gewerk: String = "Rohbau", manntage: Double, rang: Int) -> EventBauphasen.Vorgang {
        EventBauphasen.Vorgang(name: name, gewerk: gewerk, manntage: manntage, rang: rang, aufwandFehlt: manntage <= 0)
    }

    // MARK: Planung

    @Test func parallelJeRangSequenziellDazwischen() {
        // Rang 0: A (30 MT → 2 Wo bei Kolonne 3), B (15 MT → 1 Wo). Rang 1: C (45 MT → 3 Wo).
        let phasen = EventBauphasen.plane([
            vorgang("A", manntage: 30, rang: 0),
            vorgang("B", manntage: 15, rang: 0),
            vorgang("C", manntage: 45, rang: 1),
        ], kolonne: 3)

        let a = phasen.first { $0.name == "A" }!
        let b = phasen.first { $0.name == "B" }!
        let c = phasen.first { $0.name == "C" }!
        // Rang 0 startet bei Woche 0, parallel.
        #expect(a.startWoche == 0)
        #expect(b.startWoche == 0)
        #expect(a.dauerWochen == 2)   // 30 / (3×5)
        #expect(b.dauerWochen == 1)   // 15 / (3×5)
        // Rang 1 startet nach dem LÄNGSTEN aus Rang 0 (2 Wochen).
        #expect(c.startWoche == 2)
        #expect(c.dauerWochen == 3)   // 45 / (3×5)
        #expect(c.endeWoche == 5)
    }

    @Test func dauerAusManntagen() {
        // 20 Manntage, Kolonne 4 → 20/(4×5) = 1 Woche; 21 Manntage → aufgerundet 2 Wochen.
        #expect(EventBauphasen.plane([vorgang("X", manntage: 20, rang: 0)], kolonne: 4).first?.dauerWochen == 1)
        #expect(EventBauphasen.plane([vorgang("X", manntage: 21, rang: 0)], kolonne: 4).first?.dauerWochen == 2)
    }

    @Test func aufwandFehltWirdAusgewiesen() {
        // Auftrag ohne Manntage → 1 Woche Platzhalter + Hinweis, keine erfundene Zahl.
        let p = EventBauphasen.plane([vorgang("Ohne", manntage: 0, rang: 0)], kolonne: 3).first!
        #expect(p.dauerWochen == 1)
        #expect(p.beschreibung.contains("Aufwand fehlt"))
    }

    @Test func leerGibtLeer() {
        #expect(EventBauphasen.plane([], kolonne: 3).isEmpty)
    }

    // MARK: Kostengruppe → Gewerk

    @Test func kgAufGewerk() {
        #expect(EventBauphasen.gewerk(fuerKG: "311") == "Erdarbeiten")
        #expect(EventBauphasen.gewerk(fuerKG: "331") == "Rohbau")
        #expect(EventBauphasen.gewerk(fuerKG: "334") == "Fenster & Tueren")
        #expect(EventBauphasen.gewerk(fuerKG: "344") == "Fenster & Tueren")
        #expect(EventBauphasen.gewerk(fuerKG: "360") == "Dach")
        #expect(EventBauphasen.gewerk(fuerKG: "420") == "Heizung")
        #expect(EventBauphasen.gewerk(fuerKG: "444") == "Elektro")
        #expect(EventBauphasen.gewerk(fuerKG: "410") == "Sanitaer")
        #expect(EventBauphasen.gewerk(fuerKG: "520") == "Aussenanlagen")
        #expect(EventBauphasen.gewerk(fuerKG: nil) == "Allgemein")
        #expect(EventBauphasen.gewerk(fuerKG: "") == "Allgemein")
    }
}
