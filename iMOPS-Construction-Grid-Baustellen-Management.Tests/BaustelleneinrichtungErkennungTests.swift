//
//  BaustelleneinrichtungErkennungTests.swift
//  Kausalbaukette Glied 2 / Ampel: erkennt ein Auftrag die Baustelleneinrichtung?
//
//  Der Bug (live gefunden): der alte Filter suchte "einrichtung" und verfehlte
//  "Baustelle einrichten … absichern". Jetzt am Wortstamm + echtem Gewerk.
//

import Testing
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaustelleneinrichtungErkennungTests {

    @MainActor
    private func auftrag(_ titel: String, gewerk: String? = nil)
        -> (PersistenceController, Auftrag) {
        let pc = PersistenceController(inMemory: true)
        let job = Auftrag(context: pc.container.viewContext)
        job.processingDetails = titel
        if let g = gewerk {
            var e = AuftragExtrasPayload()
            e.gewerk = g
            job.extras = e.toJSONString()
        }
        return (pc, job)          // pc festhalten, sonst verliert der Kontext die Objekte
    }

    @Test @MainActor func einrichtenTrifftJetzt() {
        let (pc, job) = auftrag("Baustelle einrichten, Fläche abstecken, absichern")
        withExtendedLifetime(pc) {
            #expect(job.istBaustelleneinrichtung)   // vorher: verfehlt ("einrichten" ≠ "einrichtung")
        }
    }

    @Test @MainActor func absicherungTrifft() {
        let (pc, job) = auftrag("Fläche absichern")
        withExtendedLifetime(pc) { #expect(job.istBaustelleneinrichtung) }
    }

    @Test @MainActor func handwerkIstKeineEinrichtung() {
        let (pc, job) = auftrag("Trennvlies verlegen")
        withExtendedLifetime(pc) { #expect(!job.istBaustelleneinrichtung) }
    }

    @Test @MainActor func echtesGewerkGewinnt() {
        let (pc, job) = auftrag("Pauschale", gewerk: "Baustelleneinrichtung")
        withExtendedLifetime(pc) { #expect(job.istBaustelleneinrichtung) }
    }
}
