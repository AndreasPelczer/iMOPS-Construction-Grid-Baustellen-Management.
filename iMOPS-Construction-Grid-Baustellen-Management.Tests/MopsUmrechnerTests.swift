//
//  MopsUmrechnerTests.swift
//  Der EINE Umrechner: die Leiter Länge→Fläche→Volumen→Masse mit drei Brückenmaßen
//  (Höhe/Breite, Dicke, Dichte). Diese Tests halten jede Sprosse und den Gang über
//  mehrere Sprossen fest — und das ehrliche „nil", wenn ein Brückenmaß fehlt.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MopsUmrechnerTests {

    // MARK: - Gleiche Größenart (nichts Neues, muss aber weiter stimmen)

    @Test func gleicheGroessenartWieBisher() {
        // t → kg: „pro"-Faktor 0,001 (wie EinheitenUmrechnung).
        #expect(abs((MopsUmrechner.proFaktor(von: "t", nach: "kg") ?? 0) - 0.001) < 1e-9)
        // Absolute Menge 70 t → kg = 70000.
        #expect(MopsUmrechner.mengeUmrechnen(70, von: "t", nach: "kg") == 70000)
        // Kein Brückenmaß nötig, kein Hinweis.
        #expect(MopsUmrechner.umrechnung(von: "t", nach: "kg")?.hinweis == "")
    }

    // MARK: - Die drei einzelnen Sprossen

    @Test func sprosseDichteVolumenMasse() {
        let b = MopsUmrechner.Bruecke(dichteTproM3: 1.9)
        // 1 m³ Schotter = 1,9 t (Mengen-Faktor); der „pro"-Faktor ist der Kehrwert.
        #expect(abs((MopsUmrechner.mengeFaktor(von: "m3", nach: "t", bruecke: b) ?? 0) - 1.9) < 1e-9)
        #expect(abs((MopsUmrechner.proFaktor(von: "m3", nach: "t", bruecke: b) ?? 0) - 1.0 / 1.9) < 1e-9)
        #expect(MopsUmrechner.umrechnung(von: "m3", nach: "t", bruecke: b)?.hinweis.contains("Dichte") == true)
    }

    @Test func sprosseDickeFlaecheVolumen() {
        // 1 m² Schicht mit 0,10 m Dicke = 0,10 m³.
        let b = MopsUmrechner.Bruecke(dicke: 0.10)
        #expect(abs((MopsUmrechner.mengeFaktor(von: "m2", nach: "m3", bruecke: b) ?? 0) - 0.10) < 1e-9)
    }

    @Test func sprosseHoeheLaengeFlaeche() {
        // Der NEUE Fall: 115 m Fundament × 0,50 m Höhe = 57,5 m² Schalfläche.
        let b = MopsUmrechner.Bruecke(hoeheOderBreite: 0.50)
        #expect(abs((MopsUmrechner.mengeUmrechnen(115, von: "m", nach: "m2", bruecke: b) ?? 0) - 57.5) < 1e-9)
        // Aufwandswert 0,5 h/m² wird zu 0,25 h/m (pro laufendem Meter Fundament).
        #expect(abs((MopsUmrechner.proFaktor(von: "m2", nach: "m", bruecke: b) ?? 0) - 0.5) < 1e-9)
    }

    // MARK: - Gang über mehrere Sprossen

    @Test func mehrsprossenLaengeNachVolumen() {
        // Rohrgraben: 10 m lang, 0,8 m breit, 1,5 m tief → 12 m³.
        let b = MopsUmrechner.Bruecke(hoeheOderBreite: 0.8, dicke: 1.5)
        #expect(abs((MopsUmrechner.mengeUmrechnen(10, von: "m", nach: "m3", bruecke: b) ?? 0) - 12.0) < 1e-9)
    }

    @Test func mehrsprossenLaengeNachMasseUndZurueck() {
        // Länge → Masse braucht alle drei Sprossen (der alte Bewehrungs-Ausreißer als Kette).
        let b = MopsUmrechner.Bruecke(hoeheOderBreite: 0.02, dicke: 0.02, dichteTproM3: 7.85)
        // 1 m Stab 0,02×0,02 m, Stahl 7,85 t/m³ → 0,00314 t = 3,14 kg/m.
        let t = try? #require(MopsUmrechner.mengeUmrechnen(1, von: "m", nach: "t", bruecke: b))
        #expect(abs((t ?? 0) - 0.02 * 0.02 * 7.85) < 1e-9)
        // Hin und zurück = wieder 1 m.
        let zurueck = MopsUmrechner.mengeUmrechnen(t ?? 0, von: "t", nach: "m", bruecke: b) ?? 0
        #expect(abs(zurueck - 1.0) < 1e-9)
    }

    // MARK: - Ehrliches nil, wenn eine Sprosse fehlt

    @Test func fehlendeSprosseGibtNil() {
        // Volumen→Masse ohne Dichte → nil (der Aufrufer flaggt „Einheit prüfen").
        #expect(MopsUmrechner.proFaktor(von: "m3", nach: "t") == nil)
        // Länge→Fläche ohne Höhe → nil (genau der Schalungs-Fall vor der Brücke).
        #expect(MopsUmrechner.mengeUmrechnen(115, von: "m", nach: "m2") == nil)
        // Stück ist keine Größenart auf der Leiter → nil.
        #expect(MopsUmrechner.proFaktor(von: "Stk", nach: "m") == nil)
    }
}
