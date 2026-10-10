//
//  BaustellenMeldungTests.swift
//  Die Brücke App → Box (10.10.2026): was die App über eine Baustelle meldet.
//
//  Prüft: der Konfigurator gibt den Aufträgen Dauer und Termin mit, die Meldung trägt
//  Titel/Zeitraum/Aufträge – und KEINEN Bauherrn, keine Adresse, keine Notizen.
//  Reine Werte, kein Netz.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaustellenMeldungTests {

    // Festgehalten (nicht inline): sonst gibt der In-Memory-Stack den Container sofort frei.
    private let controller = PersistenceController(inMemory: true)

    private func testbaustelle() -> Event {
        let ctx = controller.container.viewContext
        let result = HouseProjectGenerator.generate(from: HouseProject())
        let event = HouseProjectGenerator.createEvent(from: result, into: ctx)
        event.bauherr = "Max Mustermann"            // darf die App nie verlassen
        event.bauherrStrasse = "Musterweg 1"
        return event
    }

    @Test func meldungTraegtTitelZeitraumUndAuftraege() {
        let m = BaustellenMeldung.meldung(fuer: testbaustelle())
        #expect(!m.titel.isEmpty)
        #expect(m.start != nil && m.ende != nil)
        #expect(m.auftraege.count > 3)
        #expect(m.auftraege.allSatisfy { !$0.kg.isEmpty && !$0.gewerk.isEmpty })
    }

    @Test func konfiguratorGibtDauerUndTerminMit() {
        let m = BaustellenMeldung.meldung(fuer: testbaustelle())
        let rohbau = m.auftraege.first { $0.gewerk == "Rohbau" }
        #expect(rohbau != nil)
        #expect((rohbau?.dauer_tage ?? 0) > 0)       // vorher: 0
        #expect(rohbau?.termin != nil)                // vorher: keiner
    }

    @Test func bauherrUndNotizenBleibenInDerApp() throws {
        let m = BaustellenMeldung.meldung(fuer: testbaustelle())
        let json = String(data: try JSONEncoder().encode(m), encoding: .utf8) ?? ""
        #expect(!json.contains("Mustermann"))
        #expect(!json.contains("Musterweg"))
        #expect(!json.contains("Generiert aus Haus-Konfigurator"))   // die Notizen
    }

    @Test func idIstDieBaustellennummer() {
        let e = testbaustelle()
        #expect(BaustellenMeldung.id(fuer: e) == e.eventNumber)
    }

    @Test func meldungNimmtDenGraphenMitOhneBauherr() throws {
        let event = testbaustelle()
        let koerper = try #require(BaustellenMeldung.koerper(BaustellenMeldung.meldung(fuer: event), graph: Grap8Graph.aus(event)))
        let obj = try #require(try JSONSerialization.jsonObject(with: koerper) as? [String: Any])
        let graph = try #require(obj["graph"] as? [String: Any])
        let knoten = try #require(graph["nodes"] as? [[String: Any]])
        #expect(knoten.count == (event.jobs?.count ?? -1))
        #expect(graph["edges"] is [Any])
        let text = String(decoding: koerper, as: UTF8.self)
        #expect(!text.contains("Mustermann") && !text.contains("Musterweg"))
    }
}
