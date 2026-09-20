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
        // Kein Eintrag → nil (dann zeigt der Mops keinen Vergleich).
        #expect(BKIMarktpreisKatalog.shared.eintrag(bausteinID: "GIBTS-NICHT") == nil)
    }

    /// Hier stand vorher „BET-010 ist ein Platzhalter". Am 20.09.2026 wurde BET-010 geerntet
    /// und der Test ging rot — er hielt einen Zustand fest, den das Ernten planmäßig auflöst.
    /// Ein Test darf nicht rot werden, weil jemand seine Arbeit gemacht hat. Also prüft er
    /// jetzt die Regel statt einer einzelnen Zeile: **ein Eintrag ohne echten Wert muss als
    /// Platzhalter markiert sein** — sonst behauptet der Mops einen Marktvergleich, den er
    /// nicht hat. Dass aktuell keiner mehr markiert ist, ist der gewünschte Zustand.
    @Test func keinUngeernteterWertGibtSichAlsEchterMarktpreisAus() {
        for e in BKIMarktpreisKatalog.shared.alle() where !e.platzhalter {
            #expect(e.mittel > 0,
                    "\(e.bausteinID): kein Wert, aber auch nicht als platzhalter markiert")
        }
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
