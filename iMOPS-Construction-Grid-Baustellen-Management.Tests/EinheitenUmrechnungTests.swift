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
        // Volumen gegen Masse geht NICHT direkt (braucht Dichte, siehe unten).
        #expect(EinheitenUmrechnung.proFaktor(von: "m3", nach: "t") == nil)
        // Stück ist zu nichts umrechenbar außer sich selbst.
        #expect(EinheitenUmrechnung.proFaktor(von: "Stk", nach: "kg") == nil)
        #expect(EinheitenUmrechnung.proFaktor(von: "Stk", nach: "Stk") == 1)
    }

    // MARK: - Dichte-Brücke m³↔t (Schüttgüter)

    @Test func dichteBrueckeM3NachTonne() {
        // Aufwandswert h/m³ → h/t: Schotter ~1,9 t/m³ → 1 t = 1/1,9 m³ → Faktor = 1/1,9.
        let f = try? #require(EinheitenUmrechnung.proFaktorMitDichte(von: "m3", nach: "t", dichteTproM3: 1.9))
        #expect(f != nil)
        #expect(abs((f ?? 0) - (1.0 / 1.9)) < 1e-9)
        // 15 h/m³ werden zu ~7,9 h/t.
        #expect(abs(15.0 * (f ?? 0) - 15.0 / 1.9) < 1e-9)
    }

    @Test func dichteBrueckeTonneNachM3UndZurueck() {
        // t → m³: Faktor = Dichte.
        #expect(abs((EinheitenUmrechnung.proFaktorMitDichte(von: "t", nach: "m3", dichteTproM3: 1.9) ?? 0) - 1.9) < 1e-9)
        // Nur Volumen↔Masse — Fläche geht auch mit Dichte nicht.
        #expect(EinheitenUmrechnung.proFaktorMitDichte(von: "m2", nach: "t", dichteTproM3: 1.9) == nil)
    }

    @Test func dichteKatalogErkenntSchuettgueter() {
        #expect(DichteKatalog.dichte(fuer: "Schottertragschicht 0/62mm, d= 10cm") == 1.9)
        #expect(DichteKatalog.dichte(fuer: "Frostschutzschicht einbauen") == 1.9)
        #expect(DichteKatalog.dichte(fuer: "Brechsand 0/2 liefern") == 1.6)
        // Kein Schüttgut → nil (dann kein Dichte-Weg, ehrlich flaggen).
        // WICHTIG: „Betonstahl" darf NICHT als Beton (2,4) durchgehen.
        #expect(DichteKatalog.dichte(fuer: "Betonstahlmatten verlegen") == nil)
        #expect(DichteKatalog.dichte(fuer: "") == nil)
    }
}
