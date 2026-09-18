//
//  EinheitenUmrechnungTests.swift
//  Der Bewehrungs-Ausreißer: Aufwandswert in h/t, Position in kg → ohne Umrechnung
//  Faktor 1000 daneben. Diese Tests halten die Umrechnung + das ehrliche „nicht
//  umrechenbar" fest.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct EinheitenUmrechnungTests {

    @Test func tonneNachKilogrammIstEinTausendstel() {
        let f = try? #require(EinheitenUmrechnung.proFaktor(von: "t", nach: "kg"))
        #expect(f != nil)
        #expect(abs((f ?? 0) - 0.001) < 1e-9)
        // 15 h/t werden zu 0,015 h/kg — der Bewehrungs-Fall.
        #expect(abs(15.0 * (f ?? 0) - 0.015) < 1e-9)
    }

    @Test func kilogrammNachTonneIstTausend() {
        #expect(abs((EinheitenUmrechnung.proFaktor(von: "kg", nach: "t") ?? 0) - 1000) < 1e-6)
    }

    @Test func gleicheEinheitBleibtEins() {
        #expect(EinheitenUmrechnung.proFaktor(von: "m3", nach: "m3") == 1)
        // Schreibweisen-Toleranz: m² == m2, mit/ohne Leerzeichen.
        #expect(EinheitenUmrechnung.proFaktor(von: "m²", nach: "m2") == 1)
        #expect(EinheitenUmrechnung.proFaktor(von: "lfm", nach: "lfm") == 1)
    }

    @Test func kubikmeterUndLiterRechnenRichtigHerum() {
        // „pro m³" → „pro l": m³ ist 1000× größer, also teilt sich der Wert (× 0,001).
        #expect(abs((EinheitenUmrechnung.proFaktor(von: "m3", nach: "l") ?? 0) - 0.001) < 1e-9)
        // Umgekehrt „pro l" → „pro m³": × 1000.
        #expect(abs((EinheitenUmrechnung.proFaktor(von: "l", nach: "m3") ?? 0) - 1000) < 1e-6)
    }

    @Test func verschiedeneGroessenartenSindNichtUmrechenbar() {
        // Masse gegen Fläche: kein Faktor — der Aufrufer flaggt.
        #expect(EinheitenUmrechnung.proFaktor(von: "t", nach: "m2") == nil)
        // Stück ist zu nichts umrechenbar außer sich selbst.
        #expect(EinheitenUmrechnung.proFaktor(von: "Stk", nach: "kg") == nil)
        #expect(EinheitenUmrechnung.proFaktor(von: "Stk", nach: "Stk") == 1)
    }
}
