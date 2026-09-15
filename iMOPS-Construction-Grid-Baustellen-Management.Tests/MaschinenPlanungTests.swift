//
//  MaschinenPlanungTests.swift
//  Nordstern 3+4: aus den Erdbau-Positionen (Aushub in m³) werden Bagger-Stunden
//  (Aushubmenge ÷ Leistung). Erkennung über KG 31x oder Stichwort; Leistung aus Gerät
//  oder Richtwert.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MaschinenPlanungTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func pos(_ bez: String, einheit: String, menge: Double, kg: String? = nil) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = einheit; p.menge = menge; p.kostenGruppeNummer = kg
        return p
    }

    @Test @MainActor func erkenntAushubUndRechnetBaggerStunden() {
        // 44 m³ Baugrube (KG 310) + 100 m² Pflaster (kein Erdbau) → nur die 44 zählen
        let baugrube = pos("Baugrube herstellen", einheit: "m³", menge: 44, kg: "310")
        let pflaster = pos("Betonpflaster verlegen", einheit: "m²", menge: 100, kg: "500")
        let plan = MaschinenPlanung.fuer(positionen: [baugrube, pflaster])   // Richtwert 4,4 m³/h
        #expect(plan.aushubM3 == 44)
        #expect(plan.erdbauPositionen == 1)
        #expect(abs(plan.baggerStunden - 44.0 / 4.4) < 0.001)               // = 10 h
        #expect(abs(plan.baggerTage - 10.0 / 8.0) < 0.001)                  // 1,25 Tage
    }

    @Test @MainActor func erkennungPerStichwortOhneKG() {
        let p = pos("Oberboden abtragen und lagern", einheit: "m³", menge: 20)   // kein KG, Stichwort „oberboden/abtragen"
        let plan = MaschinenPlanung.fuer(positionen: [p])
        #expect(plan.aushubM3 == 20)
    }

    @Test @MainActor func eigeneGeraeteleistungGewinnt() {
        let baugrube = pos("Aushub", einheit: "m³", menge: 100, kg: "310")
        let plan = MaschinenPlanung.fuer(positionen: [baugrube], leistung: 25.0, quelle: "Bagger 9t")
        #expect(plan.leistungM3h == 25.0)
        #expect(plan.quelleLeistung == "Bagger 9t")
        #expect(abs(plan.baggerStunden - 4.0) < 0.001)                      // 100 ÷ 25 = 4 h
    }

    @Test @MainActor func keinAushubKeineMaschine() {
        let p = pos("Pflaster", einheit: "m²", menge: 100, kg: "500")
        let plan = MaschinenPlanung.fuer(positionen: [p])
        #expect(!plan.hatAushub)
        #expect(plan.aushubM3 == 0)
    }
}
