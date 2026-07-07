//
//  EventExtrasImportHerkunftTests.swift
//  Metadaten-Persistenz (Schritt 1 der Baustellen-Ist-Übersicht):
//  ExtractMetadata → EventExtrasPayload.importHerkunft.
//  Kritischer Punkt: das neue Feld ist OPTIONAL → alte gespeicherte Blobs
//  (ohne importHerkunft) müssen weiter dekodieren, sonst gingen Checkliste/
//  houseProject beim Laden verloren.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct EventExtrasImportHerkunftTests {

    @Test func altesExtrasOhneImportHerkunftBleibtDekodierbar() throws {
        let alt = """
        {"checklist": [{"id":"a","title":"Fundament","isDone":false}],
         "pinnedProductIDs": [], "pinnedLexikonCodes": []}
        """
        let payload = try JSONDecoder().decode(EventExtrasPayload.self, from: Data(alt.utf8))
        #expect(payload.checklist.count == 1)
        #expect(payload.importHerkunft == nil)   // fehlender Schlüssel → nil, kein Fehler
    }

    @Test func importHerkunftRoundTrip() throws {
        var p = EventExtrasPayload()
        p.importHerkunft = ImportHerkunft(
            projekt: "I-25_448", baustelle: "Marktbreit",
            datei: "aura125-lv.json", importiertAm: nil)
        let data = try JSONEncoder().encode(p)
        let zurueck = try JSONDecoder().decode(EventExtrasPayload.self, from: data)
        #expect(zurueck.importHerkunft?.projekt == "I-25_448")
        #expect(zurueck.importHerkunft?.baustelle == "Marktbreit")
        #expect(zurueck.importHerkunft?.datei == "aura125-lv.json")
    }
}
