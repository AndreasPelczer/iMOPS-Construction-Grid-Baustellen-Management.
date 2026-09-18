//
//  BaugrubeTests.swift
//  Baugruben-Aushub: Grundfläche × Tiefe, optional Arbeitsraum + Böschung.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaugrubeTests {

    @Test func senkrechtOhneArbeitsraumIstFlaecheMalTiefe() {
        let e = Baugrube.aushub(laenge: 10, breite: 8, tiefe: 1.5,
                                arbeitsraum: 0, boeschung: .senkrecht)
        #expect(e.grundflaeche == 80)
        #expect(e.sohleFlaeche == 80)
        #expect(abs(e.volumen - 120) < 1e-9)   // 10×8×1,5
    }

    @Test func mitArbeitsraum() {
        // Arbeitsraum 0,5 m rundum → Sohle 11×9 = 99 m², senkrecht → V = 99 × 1,5.
        let e = Baugrube.aushub(laenge: 10, breite: 8, tiefe: 1.5,
                                arbeitsraum: 0.5, boeschung: .senkrecht)
        #expect(e.sohleFlaeche == 99)
        #expect(abs(e.volumen - 148.5) < 1e-9)
    }

    @Test func boeschungBrauchtMehr() {
        // 45° geböscht (n=1), kein Arbeitsraum: oben 13×11, Prismatoid → 165 m³ > 120.
        let e = Baugrube.aushub(laenge: 10, breite: 8, tiefe: 1.5,
                                arbeitsraum: 0, boeschung: .mittel)
        #expect(e.obenFlaeche == 143)          // (10+3)×(8+3)
        #expect(abs(e.volumen - 165) < 1e-9)
        #expect(e.volumen > 120)               // mehr als senkrecht
    }
}
