//
//  UebergabeZweiseitigTests.swift
//  Zweiseitige Übergabe (Buch): Abgabe → Annahme mit Ergebnis.
//
//  Prüft die Zustandsmaschine: abgegeben ohne Annahme = offene Lücke (die der Mops
//  meldet), Annahme schließt sie, ein Befund (Problem/geht nicht) hält die Kette nicht.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct UebergabeZweiseitigTests {

    @MainActor
    private func auftrag(_ bauen: (inout AuftragExtrasPayload) -> Void)
        -> (PersistenceController, Auftrag) {
        let pc = PersistenceController(inMemory: true)
        let job = Auftrag(context: pc.container.viewContext)
        var e = AuftragExtrasPayload()
        bauen(&e)
        job.extras = e.toJSONString()
        return (pc, job)
    }

    @Test @MainActor func frischKeineUebergabe() {
        let (pc, job) = auftrag { _ in }
        withExtendedLifetime(pc) {
            #expect(!job.istAbgegeben)
            #expect(!job.uebergabeOffen)
        }
    }

    @Test @MainActor func abgegebenOhneAnnahmeIstDieOffeneLuecke() {
        let (pc, job) = auftrag { $0.abgegebenVon = "Mitarbeiter"; $0.abgegebenAm = Date() }
        withExtendedLifetime(pc) {
            #expect(job.istAbgegeben)
            #expect(job.uebergabeOffen)        // das meldet der Mops
            #expect(!job.istAngenommen)
        }
    }

    @Test @MainActor func annahmeSchliesstDieLuecke() {
        let (pc, job) = auftrag {
            $0.abgegebenVon = "Mitarbeiter"; $0.abgegebenAm = Date()
            $0.angenommenVon = "Leitung"; $0.angenommenAm = Date()
            $0.annahmeErgebnis = Annahmeergebnis.ok.rawValue
        }
        withExtendedLifetime(pc) {
            #expect(!job.uebergabeOffen)
            #expect(job.annahmeErgebnis == .ok)
            #expect(!job.annahmeMitBefund)
        }
    }

    @Test @MainActor func annahmeMitProblemIstBefundNichtLuecke() {
        let (pc, job) = auftrag {
            $0.abgegebenVon = "Mitarbeiter"; $0.abgegebenAm = Date()
            $0.angenommenVon = "Leitung"; $0.angenommenAm = Date()
            $0.annahmeErgebnis = Annahmeergebnis.problem.rawValue
        }
        withExtendedLifetime(pc) {
            #expect(!job.uebergabeOffen)       // angenommen → keine Lücke mehr
            #expect(job.annahmeMitBefund)      // aber ein sichtbarer Befund
        }
    }

    @Test func nurOkHaeltDieKette() {
        #expect(Annahmeergebnis.ok.haeltDieKette)
        #expect(!Annahmeergebnis.problem.haeltDieKette)
        #expect(!Annahmeergebnis.gehtNicht.haeltDieKette)
    }
}
