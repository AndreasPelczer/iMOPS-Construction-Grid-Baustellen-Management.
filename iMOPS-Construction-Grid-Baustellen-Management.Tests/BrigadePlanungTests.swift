//
//  BrigadePlanungTests.swift
//  Die Brücke Kalkulation → Brigade: Mannstunden aus dem LV → Manntage → Arbeitstage.
//  Ehrlich: Positionen ohne Aufwandswert tragen 0 bei und werden ausgewiesen.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BrigadePlanungTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Position mit Aufwandswert (Lohnstunden je Einheit) über den Katalog-Service.
    @MainActor
    private func position(_ bez: String, menge: Double, maurer: Double, helfer: Double) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = "m²"; p.menge = menge
        if maurer > 0 || helfer > 0 {
            LeistungskatalogService.schreibeAufwandAlsLohn(maurer: maurer, helfer: helfer, auf: p, in: ctx)
        }
        return p
    }

    /// Rollen-Aufschlüsselung: die Brigade weiß jetzt WER gebraucht wird (echte Kolonne).
    @Test @MainActor func rollenAufschluesselung() {
        // Rohrgraben: 320 m × 0,30 h/m, Kolonne „1 Baggerfahrer + 1 Helfer" → je 0,15 h/m.
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Rohrgraben"; pos.einheit = "m"; pos.menge = 320
        LeistungskatalogService.schreibeAufwandAusKolonne(mittelStunden: 0.30, kolonne: "1 Baggerfahrer + 1 Helfer", auf: pos, in: ctx)

        let plan = BrigadePlanung.fuer(positionen: [pos])
        let rollen = Dictionary(uniqueKeysWithValues: plan.rollen.map { ($0.rolle, $0.stunden) })
        // 0,15 h/m × 320 m = 48 Mannstunden je Rolle
        #expect(abs((rollen["Baggerfahrer"] ?? 0) - 48) < 0.01)
        #expect(abs((rollen["Helfer"] ?? 0) - 48) < 0.01)
        // Summe der Rollen = Gesamt-Mannstunden
        #expect(abs(plan.rollen.reduce(0) { $0 + $1.stunden } - 96) < 0.01)
    }

    @Test @MainActor func mannstundenManntageArbeitstage() {
        // 100 m² × (0,3 + 0,2) h/m² = 50 Mannstunden
        let pos = position("Pflaster", menge: 100, maurer: 0.3, helfer: 0.2)
        let plan = BrigadePlanung.fuer(positionen: [pos])
        #expect(abs(plan.mannstunden - 50) < 0.01)
        #expect(abs(plan.manntage - 50.0 / 8.0) < 0.01)              // 6,25 Manntage
        #expect(abs((plan.arbeitstage(beiLeuten: 2) ?? 0) - 3.125) < 0.01)  // 2 Leute → 3,125 Tage
        #expect(plan.arbeitstage(beiLeuten: 0) == nil)              // keine Division durch 0
        #expect(!plan.unvollstaendig)                               // alle haben Aufwand
    }

    @Test @MainActor func positionenOhneAufwandZaehlen0UndWerdenAusgewiesen() {
        let mitAufwand = position("Pflaster", menge: 100, maurer: 0.3, helfer: 0.2)   // 50 h
        let ohneAufwand = position("Randsteine", menge: 40, maurer: 0, helfer: 0)     // 0 h (Aufwand fehlt)
        let plan = BrigadePlanung.fuer(positionen: [mitAufwand, ohneAufwand])
        #expect(abs(plan.mannstunden - 50) < 0.01)                 // nur die mit Aufwand
        #expect(plan.positionenGesamt == 2)
        #expect(plan.positionenOhneAufwand == 1)
        #expect(plan.unvollstaendig)                               // Summe ist unvollständig
    }

    @Test @MainActor func leeresLVIstNull() {
        let plan = BrigadePlanung.fuer(positionen: [])
        #expect(plan.mannstunden == 0)
        #expect(plan.positionenOhneAufwand == 0)
        #expect(!plan.unvollstaendig)
    }
}
