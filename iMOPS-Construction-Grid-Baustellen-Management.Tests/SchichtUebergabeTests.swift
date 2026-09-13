//
//  SchichtUebergabeTests.swift
//  Schichtübergabe: EIN Klick übernimmt die Verantwortung für die ganze Baustelle.
//
//  Prüft: alle offenen Aufträge werden in einem Akt angenommen, und eine über Nacht
//  offene Übergabe-Lücke schließt sich dadurch.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct SchichtUebergabeTests {

    @MainActor
    private func baustelle(_ n: Int, gesternAbgegeben: Bool = false)
        -> (PersistenceController, Event) {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        let event = Event(context: ctx)
        for i in 0..<n {
            let job = Auftrag(context: ctx)
            job.processingDetails = "Auftrag \(i)"
            job.status = .pending
            job.event = event
            if gesternAbgegeben {
                var e = AuftragExtrasPayload()
                e.abgegebenVon = "Mitarbeiter"
                e.abgegebenAm = Date(timeIntervalSinceNow: -86_400)   // gestern
                job.extras = e.toJSONString()
            }
        }
        return (pc, event)
    }

    @Test @MainActor func frischNichtUebernommen() {
        let (pc, ev) = baustelle(2)
        withExtendedLifetime(pc) {
            #expect(ev.offeneAuftraege.count == 2)
            #expect(!ev.schichtHeuteUebernommen)
        }
    }

    @Test @MainActor func einKlickUebernimmtAlle() {
        let (pc, ev) = baustelle(3)
        withExtendedLifetime(pc) {
            ev.schichtUebernehmen(rolle: "Mitarbeiter", ergebnis: .ok)
            #expect(ev.schichtHeuteUebernommen)
            #expect(ev.schichtUebernommenVon == "Mitarbeiter")
        }
    }

    @Test @MainActor func uebernahmeSchliesstDieNachtLuecke() {
        let (pc, ev) = baustelle(2, gesternAbgegeben: true)
        withExtendedLifetime(pc) {
            #expect(ev.offeneAuftraege.allSatisfy { $0.uebergabeOffen })   // Lücke offen
            #expect(ev.hatOffeneUebergabe)
            ev.schichtUebernehmen(rolle: "Leitung", ergebnis: .ok)
            #expect(ev.offeneAuftraege.allSatisfy { !$0.uebergabeOffen })  // Lücke zu
            #expect(!ev.hatOffeneUebergabe)
        }
    }

    @Test @MainActor func feierabendAbgebenOeffnetDieUebergabe() {
        let (pc, ev) = baustelle(2)
        withExtendedLifetime(pc) {
            #expect(!ev.hatOffeneUebergabe)             // noch nichts abgegeben
            ev.schichtAbgeben(rolle: "Mitarbeiter")
            #expect(ev.offeneAuftraege.allSatisfy { $0.istAbgegeben })
            #expect(ev.hatOffeneUebergabe)              // abgegeben, wartet auf Übernahme
            #expect(!ev.schichtHeuteUebernommen)
        }
    }

    @Test @MainActor func feierabendDannUebernehmen_rundeSchleife() {
        let (pc, ev) = baustelle(2)
        withExtendedLifetime(pc) {
            ev.schichtAbgeben(rolle: "Mitarbeiter")     // Feierabend
            #expect(ev.hatOffeneUebergabe)
            ev.schichtUebernehmen(rolle: "Leitung", ergebnis: .ok)  // nächster Morgen
            #expect(!ev.hatOffeneUebergabe)             // Kette hält wieder
            #expect(ev.schichtHeuteUebernommen)
        }
    }
}
