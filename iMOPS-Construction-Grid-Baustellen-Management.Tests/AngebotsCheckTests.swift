//
//  AngebotsCheckTests.swift
//  Beweist den Angebots-Wächter: Position ohne Preis / ohne Menge wird gemeldet,
//  Überschrift und Alternative NICHT, ein vollständiges Angebot ist leer.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AngebotsCheckTests {

    private func posten(_ id: String, _ name: String, einheit: String = "m2",
                        menge: Double = 1, ep: Double = 10, alt: Bool = false) -> AngebotsPosten {
        AngebotsPosten(id: id, bezeichnung: name, einheit: einheit, menge: menge,
                       einzelpreis: ep, istAlternative: alt)
    }

    @Test func ohnePreisWirdGemeldet() {
        let l = AngebotsCheck.pruefe([posten("1", "Pflaster", ep: 0)])
        #expect(l.contains { $0.posID == "1" && $0.art == .ohnePreis })
    }

    @Test func ohneMengeWirdGemeldet() {
        let l = AngebotsCheck.pruefe([posten("1", "Pflaster", menge: 0)])
        #expect(l.contains { $0.posID == "1" && $0.art == .ohneMenge })
    }

    @Test func ueberschriftIstKeineLuecke() {
        // Titel: keine Menge, keine Einheit, kein Preis → Gliederung, nicht mahnen
        let l = AngebotsCheck.pruefe([posten("t", "Erdarbeiten", einheit: "", menge: 0, ep: 0)])
        #expect(l.isEmpty)
    }

    @Test func alternativeZaehltNicht() {
        let l = AngebotsCheck.pruefe([posten("a", "Alt-Pflaster", menge: 0, ep: 0, alt: true)])
        #expect(l.isEmpty)
    }

    @Test func vollstaendigesAngebotIstLeer() {
        let l = AngebotsCheck.pruefe([
            posten("1", "Pflaster", menge: 100, ep: 58),
            posten("2", "Schotter", einheit: "t", menge: 12, ep: 20),
        ])
        #expect(l.isEmpty)
    }
}
