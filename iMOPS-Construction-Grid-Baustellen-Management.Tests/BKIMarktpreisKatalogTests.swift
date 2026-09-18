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
        // Die Struktur-Beispiele sind da (Platzhalter), keyed über die STLB-Baustein-ID.
        let e = BKIMarktpreisKatalog.shared.eintrag(bausteinID: "STR-002")
        #expect(e != nil)
        #expect(e?.einheit == "m3")
        #expect(e?.min == 22)
        #expect(e?.mittel == 30)
        #expect(e?.max == 42)
        #expect(e?.platzhalter == true)   // noch kein echter BKI-Wert
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
