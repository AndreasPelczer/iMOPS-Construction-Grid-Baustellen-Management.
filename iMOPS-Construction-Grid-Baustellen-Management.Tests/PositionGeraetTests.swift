//
//  PositionGeraetTests.swift
//  Geräte pauschal (Fuhren/Pauschale): Anzahl × Preis je Einheit = Gesamt, ÷ Menge = je Einheit.
//  Der ehrliche Ersatz für den alten „6 Fahrten als 0,06 Stunden"-Hack.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct PositionGeraetTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test @MainActor func pauschalTeiltDurchMenge() {
        let pos = LVPosition(context: ctx)
        pos.einheit = "m²"; pos.menge = 100

        // LKW: 6 Fahrten × 120 € = 720 € gesamt; ÷ 100 m² = 7,20 €/m².
        let lkw = PositionGeraet(context: ctx)
        lkw.geraetName = "LKW-Fuhren"; lkw.stunden = 6; lkw.kostenProStunde = 120
        lkw.pauschal = true; lkw.einheit = "Fahrt"; lkw.position = pos
        #expect(abs(lkw.kostenGesamt - 720) < 0.001)
        #expect(abs(lkw.kostenProEinheit - 7.20) < 0.001)
        #expect(lkw.zaehlEinheit == "Fahrt")
    }

    @Test @MainActor func zeitGeraetUnveraendert() {
        let pos = LVPosition(context: ctx)
        pos.einheit = "m²"; pos.menge = 100
        let bagger = PositionGeraet(context: ctx)
        bagger.geraetName = "Minibagger"; bagger.stunden = 0.08; bagger.kostenProStunde = 65
        bagger.pauschal = false; bagger.position = pos
        #expect(abs(bagger.kostenProEinheit - 5.20) < 0.001)   // 0,08 h/m² × 65 €/h
        #expect(abs(bagger.kostenGesamt - 520) < 0.001)        // 5,20 × 100 m²
        #expect(bagger.zaehlEinheit == "h")                    // einheit nil → "h"
    }

    @Test @MainActor func mengeNullKeineDivisionDurchNull() {
        let pos = LVPosition(context: ctx)
        pos.einheit = "m²"; pos.menge = 0
        let lkw = PositionGeraet(context: ctx)
        lkw.stunden = 6; lkw.kostenProStunde = 120; lkw.pauschal = true; lkw.position = pos
        #expect(lkw.kostenProEinheit == 0)
    }
}
