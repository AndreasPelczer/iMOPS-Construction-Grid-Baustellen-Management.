//
//  AuswertungLVMapperTests.swift
//  Brücke /extract-doc → LV: Erschließungs-Fakten werden zu LV-Vorschlägen und
//  (nur bestätigt) zu LVPositionen. Herkunft = geschätzt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AuswertungLVMapperTests {

    @MainActor private static let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { Self.controller.container.viewContext }

    private func erschliessung() -> ExtractDocResult {
        let json = """
        {"status":"success","quelle":"erschliessung.pdf","doctype_erkannt":"erschliessung",
         "confidence":0.8,"model":"gpt-4.1","meldung":"Entwurf, prüfen.",
         "felder":{"medien":[
            {"medium":"Kanal","dimension":"DN150","laenge_m":12.0,"hinweis":"an Straße"},
            {"medium":"Wasser","dimension":"63 PE"}
         ],"rueckstauebene_mNN":102.3}}
        """
        return try! JSONDecoder().decode(ExtractDocResult.self, from: Data(json.utf8))
    }

    @Test func erschliessungWirdZuVorschlaegen() {
        let v = AuswertungLVMapper.vorschlaege(aus: erschliessung())
        #expect(v.count == 2)

        let kanal = try! #require(v.first { $0.bezeichnung.contains("Kanal") })
        #expect(kanal.bezeichnung == "Hausanschluss Kanal DN150")
        #expect(kanal.menge == 12.0)
        #expect(kanal.einheit == "m")
        #expect(kanal.kostenGruppe == "200")
        #expect(kanal.quellDatei == "erschliessung.pdf")

        // Wasser ohne Länge → Menge 0 + Hinweis, nichts wird geraten.
        let wasser = try! #require(v.first { $0.bezeichnung.contains("Wasser") })
        #expect(wasser.menge == 0)
        #expect(wasser.hinweis?.contains("Länge fehlt") == true)
    }

    @Test @MainActor func uebernehmenLegtNurSelektierteAn() throws {
        let event = Event(context: ctx)
        var v = AuswertungLVMapper.vorschlaege(aus: erschliessung())
        v[1].istSelektiert = false   // Wasser abwählen

        let neu = AuswertungLVMapper.uebernehmen(v, in: ctx, event: event)
        #expect(neu.count == 1)
        let pos = try #require(neu.first)
        #expect(pos.bezeichnung == "Hausanschluss Kanal DN150")
        #expect(pos.menge == 12.0)
        #expect(pos.einheit == "m")
        #expect(pos.mengenQuelle == .schaetzung)   // aus Dokument gefolgert → geschätzt (ehrlich)
        #expect(pos.event === event)
    }

    @Test func nochNichtAngebundeneDoctypesGebenNichts() {
        let json = """
        {"status":"success","quelle":"boden.pdf","doctype_erkannt":"bodengutachten",
         "confidence":0.8,"model":"gpt-4.1","meldung":"x","felder":{"bodenklassen":["BK4"]}}
        """
        let res = try! JSONDecoder().decode(ExtractDocResult.self, from: Data(json.utf8))
        #expect(AuswertungLVMapper.vorschlaege(aus: res).isEmpty)   // Bodengutachten: eigener Schritt, folgt
    }
}
