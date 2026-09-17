//
//  ErdmassenTests.swift
//  Bogen 1: Cut & Fill aus dem Höhenraster, DGM1-XYZ-Parser, und die Anbindung an die
//  vorhandene Bagger-Kette (MaschinenPlanung).
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ErdmassenTests {

    // MARK: Cut/Fill gegen ein Planum

    @Test func abtragGegenEbene() {
        // 3×3 Raster, alles 10 m hoch, 1 m Gitter, Planum 8 m → nur Abtrag.
        let dgm = Gelaendemodell(hoehen: Array(repeating: Array(repeating: 10.0, count: 3), count: 3))!
        let m = ErdmassenRechner.gegenEbene(dgm, zielHoehe: 8.0)
        #expect(abs(m.abtragM3 - 18.0) < 1e-9)   // 9 Zellen × 2 m × 1 m²
        #expect(m.auftragM3 == 0)
        #expect(abs(m.flaecheM2 - 9.0) < 1e-9)
        #expect(m.zellen == 9)
    }

    @Test func abtragUndAuftrag() {
        // 2×2: [[12,8],[8,4]], Planum 8 → oben-links Abtrag 4, unten-rechts Auftrag 4.
        let dgm = Gelaendemodell(hoehen: [[12, 8], [8, 4]])!
        let m = ErdmassenRechner.gegenEbene(dgm, zielHoehe: 8.0)
        #expect(abs(m.abtragM3 - 4.0) < 1e-9)
        #expect(abs(m.auftragM3 - 4.0) < 1e-9)
        #expect(abs(m.nettoM3 - 0.0) < 1e-9)
    }

    @Test func massenausgleichIstDieMittlereHoehe() {
        let dgm = Gelaendemodell(hoehen: [[12, 8], [8, 4]])!
        let a = ErdmassenRechner.massenausgleich(dgm)
        #expect(abs(a.hoehe - 8.0) < 1e-9)                 // Mittelwert
        #expect(abs(a.massen.abtragM3 - a.massen.auftragM3) < 1e-9)  // Cut = Fill
    }

    @Test func gegenGeplanteFlaeche() {
        let dgm = Gelaendemodell(hoehen: [[10, 10]])!
        let ziel = Gelaendemodell(hoehen: [[8, 8]])!
        let m = ErdmassenRechner.gegenFlaeche(dgm, ziel: ziel)
        #expect(m != nil)
        #expect(abs((m?.abtragM3 ?? 0) - 4.0) < 1e-9)      // 2 Zellen × 2 m
        // Nicht passende Raster → nil (keine erfundene Zahl).
        let schief = Gelaendemodell(hoehen: [[8, 8, 8]])!
        #expect(ErdmassenRechner.gegenFlaeche(dgm, ziel: schief) == nil)
    }

    // MARK: DGM1-XYZ-Parser

    @Test func xyzWirdZuRaster() {
        // 2×2-Gitter, 1 m Abstand. Y wird absteigend geordnet (Norden oben).
        let xyz = """
        0 0 4
        1 0 8
        0 1 8
        1 1 12
        """
        let dgm = Gelaendemodell.ausXYZ(xyz)
        #expect(dgm != nil)
        guard let dgm else { return }
        #expect(abs(dgm.dx - 1.0) < 1e-9)
        #expect(abs(dgm.dy - 1.0) < 1e-9)
        #expect(dgm.zellen == 4)
        #expect(abs(dgm.mittlereHoehe - 8.0) < 1e-9)
        // Planum 6 → Abtrag der Zellen über 6 (8,12,8), Auftrag der Zelle 4.
        let m = ErdmassenRechner.gegenEbene(dgm, zielHoehe: 6.0)
        #expect(abs(m.abtragM3 - 10.0) < 1e-9)   // (8-6)+(12-6)+(8-6) = 2+6+2
        #expect(abs(m.auftragM3 - 2.0) < 1e-9)   // (6-4)
    }

    // MARK: Anbindung an die Bagger-Kette

    @Test @MainActor func aushubFliesstInDieMaschinenkette() {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        let dgm = Gelaendemodell(hoehen: Array(repeating: Array(repeating: 10.0, count: 10), count: 10))!
        let m = ErdmassenRechner.gegenEbene(dgm, zielHoehe: 8.0)   // 100 Zellen × 2 m = 200 m³

        // So legt der Bogen-1-Weg die Aushub-Position an (m³, KG 311 „Baugrube").
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Bodenaushub Baugrube"
        pos.einheit = "m³"
        pos.menge = m.aushubM3
        pos.kostenGruppeNummer = "311"

        #expect(MaschinenPlanung.istAushub(pos))
        let plan = MaschinenPlanung.fuer(positionen: [pos], leistung: Erdbauleistung.bagger5t, quelle: "Bagger 5t")
        #expect(abs(plan.aushubM3 - 200.0) < 1e-9)
        // Bagger-Stunden = 200 m³ ÷ 12 m³/h
        #expect(abs(plan.baggerStunden - 200.0 / 12.0) < 1e-6)
    }
}
