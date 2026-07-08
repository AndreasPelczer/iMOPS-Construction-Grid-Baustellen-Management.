//
//  AufwandEingabeFeldTests.swift
//  Umrechnung "je Einheit / gesamt" (§2.4). Gespeichert wird immer der Wert je Einheit;
//  der "gesamt"-Modus teilt durch die Positions-Menge. Kein Rundungsverlust bei sauberen Werten.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AufwandEingabeFeldTests {

    @Test func jeEinheitModusGibtRohwert() {
        #expect(AufwandEingabeFeld.jeEinheit(text: "0,5", gesamt: false, menge: 120) == 0.5)
    }

    @Test func gesamtModusTeiltDurchMenge() {
        let je = AufwandEingabeFeld.jeEinheit(text: "6", gesamt: true, menge: 120)
        #expect(abs(je - 0.05) < 1e-9)   // 6 / 120 = 0,05
    }

    @Test func gesamtOhneMengeIstNull() {
        // Division durch 0 abgefangen → 0 (im UI ist das Feld dann deaktiviert)
        #expect(AufwandEingabeFeld.jeEinheit(text: "6", gesamt: true, menge: 0) == 0)
    }

    @Test func roundTripGesamtJeEinheitGesamt() {
        // DoD: 6 h gesamt bei 120 → speichert 0,05 je Einheit → zurück im gesamt-Modus wieder 6
        let je = AufwandEingabeFeld.jeEinheit(text: "6", gesamt: true, menge: 120)
        let zurueck = AufwandEingabeFeld.format(je * 120)
        #expect(AufwandEingabeFeld.parse(zurueck) == 6)
    }

    @Test func parseDeutschesKomma() {
        #expect(AufwandEingabeFeld.parse("1,5") == 1.5)
    }

    @Test func formatOhneTausenderTrennungReParsebar() {
        // 1234,5 darf nicht als "1.234,5" formatiert werden — sonst bricht das Re-Parsen
        let s = AufwandEingabeFeld.format(1234.5)
        #expect(AufwandEingabeFeld.parse(s) == 1234.5)
    }
}
