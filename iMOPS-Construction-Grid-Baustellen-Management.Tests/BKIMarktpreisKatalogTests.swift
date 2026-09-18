//
//  BKIMarktpreisKatalogTests.swift
//  Das BKI-Orakel: Marktpreise (min–von–mittel–bis–max) je STLB-Baustein als Referenz.
//  Diese Tests halten Laden + Umrechnung des Marktpreises in die Positions-Einheit fest.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BKIMarktpreisKatalogTests {

    @Test func yamlLaedtUndFindetProBaustein() {
        // Echte BKI-Werte (Main-Tauber, netto), keyed über die STLB-Baustein-ID.
        // Nur der Ø/Mittelwert ist Pflicht; die volle Spanne (min/max) optional.
        let e = BKIMarktpreisKatalog.shared.eintrag(bausteinID: "STR-002")
        #expect(e != nil)
        #expect(e?.einheit == "m2")
        #expect(e?.mittel == 19)
        #expect(e?.min == nil)            // nur Ø geerntet, keine Spanne
        #expect(e?.platzhalter == false)  // echter Wert
        #expect(e?.spanneText == "19 €/m2 (Ø)")
        // Platzhalter (noch nicht geerntet) ist als solcher markiert.
        #expect(BKIMarktpreisKatalog.shared.eintrag(bausteinID: "BET-010")?.platzhalter == true)
        // Kein Eintrag → nil (dann zeigt der Mops keinen Vergleich).
        #expect(BKIMarktpreisKatalog.shared.eintrag(bausteinID: "GIBTS-NICHT") == nil)
    }

    @Test @MainActor func marktpreisWirdInPositionsEinheitUmgerechnet() {
        // BKI führt Schotter je m³, die Position rechnet in t → über die Dichte vergleichbar.
        // 30 €/m³ Schotter (1,9 t/m³) → je t = 30 / 1,9 ≈ 15,79 €/t.
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Schottertragschicht 0/62mm, d= 10cm"; pos.einheit = "t"; pos.menge = 70
        let jeT = AutoKalkulationsService.preisInPositionsEinheit(30, vonEinheit: "m3", pos: pos)
        #expect(jeT != nil)
        #expect(abs((jeT ?? 0) - 30.0 / 1.9) < 1e-6)
    }
}
