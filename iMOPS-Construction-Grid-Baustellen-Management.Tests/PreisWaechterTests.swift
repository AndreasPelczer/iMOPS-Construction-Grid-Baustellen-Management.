//
//  PreisWaechterTests.swift
//  Beweist den Preis-Wächter (Spike): Komma-Falle + robuster Ausreißer,
//  je Einheit getrennt, kein Fehlalarm bei normaler Streuung.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct PreisWaechterTests {

    /// Die Stützwinkel-Falle: 4 Pflaster ~58 €/m², eins mit verrutschtem Komma (5,80).
    @Test func kommaFehlerWirdErkannt() {
        let punkte = [
            PreisPunkt(id: "1", bezeichnung: "Pflaster A", einheit: "m2", einzelpreis: 58),
            PreisPunkt(id: "2", bezeichnung: "Pflaster B", einheit: "m2", einzelpreis: 61),
            PreisPunkt(id: "3", bezeichnung: "Pflaster C", einheit: "m2", einzelpreis: 55),
            PreisPunkt(id: "4", bezeichnung: "Pflaster D", einheit: "m2", einzelpreis: 5.8),
        ]
        let befunde = PreisWaechter.pruefe(punkte)
        #expect(befunde.contains { $0.punktID == "4" && $0.art == .zehnerpotenz })
    }

    /// Normale Preisstreuung darf NICHT alarmieren (sonst nervt der Wächter).
    @Test func normaleStreuungKeinAlarm() {
        let punkte = (1...6).map {
            PreisPunkt(id: "\($0)", bezeichnung: "P\($0)", einheit: "m2", einzelpreis: Double(50 + $0 * 2))
        }
        #expect(PreisWaechter.pruefe(punkte).isEmpty)
    }

    /// Verschiedene Einheiten werden getrennt verglichen (m² nicht gegen Stück).
    @Test func einheitenGetrennt() {
        var punkte = (1...4).map {
            PreisPunkt(id: "m\($0)", bezeichnung: "m\($0)", einheit: "m2", einzelpreis: 50)
        }
        punkte += [
            PreisPunkt(id: "s1", bezeichnung: "Stück 1", einheit: "St", einzelpreis: 80),
            PreisPunkt(id: "s2", bezeichnung: "Stück 2", einheit: "St", einzelpreis: 82),
            PreisPunkt(id: "s3", bezeichnung: "Stück 3", einheit: "St", einzelpreis: 79),
            PreisPunkt(id: "s4", bezeichnung: "Stück 4", einheit: "St", einzelpreis: 8100),
        ]
        let befunde = PreisWaechter.pruefe(punkte)
        #expect(befunde.contains { $0.punktID == "s4" })
        #expect(!befunde.contains { $0.punktID.hasPrefix("m") })
    }

    /// Zu wenige gleichartige Positionen → lieber schweigen als raten.
    @Test func zuKleineGruppeSchweigt() {
        let punkte = [
            PreisPunkt(id: "1", bezeichnung: "A", einheit: "m3", einzelpreis: 100),
            PreisPunkt(id: "2", bezeichnung: "B", einheit: "m3", einzelpreis: 9999),
        ]
        #expect(PreisWaechter.pruefe(punkte).isEmpty)
    }
}
