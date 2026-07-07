//
//  LVJSONImportTests.swift
//  Deliverable #3 — LV-Import aus JSON-Datei (ExtractPlanResult)
//
//  Fährt genau den Code, den der Button „LV aus JSON-Datei" auslöst:
//  JSONDecoder().decode(ExtractPlanResult) -> ExtractPlanMapper.toParsed.
//  Kein System-Dateipicker (der ist nicht zuverlässig automatisierbar); die
//  Datei-Auswahl selbst ist reine Glue, gespiegelt vom bewiesenen PDF-Weg.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LVJSONImportTests {

    // Nur lv_positionen — bestellliste/etiketten/metadata FEHLEN.
    // Muss dank ExtractPlanResult.init(from:) trotzdem dekodieren (Robustheit
    // für extern per Vision erzeugte JSONs, die nur Positionen enthalten).
    @Test func decodesJSONMissingBestelllisteAndEtiketten() throws {
        let json = """
        {"lv_positionen": [
          {"posNr": "01.01.01", "bezeichnung": "Oberboden abtragen", "einheit": "m³", "menge": 35.153, "kg": null, "quelle": "vision"},
          {"posNr": "03.01.02", "bezeichnung": "Bodenplattenbeton", "einheit": "m²", "menge": 78, "kg": null, "quelle": "vision"}
        ]}
        """
        let result = try JSONDecoder().decode(ExtractPlanResult.self, from: Data(json.utf8))
        #expect(result.lvPositionen.count == 2)
        #expect(result.bestellliste.isEmpty)
        #expect(result.etiketten.hart.isEmpty && result.etiketten.geschaetzt.isEmpty)

        let parsed = ExtractPlanMapper.toParsed(result)
        #expect(parsed.count == 2)
        #expect(parsed[0].posNr == "01.01.01")
        #expect(parsed[0].menge == 35.153)
        #expect(parsed[0].einheit == "m³")
        #expect(parsed[1].menge == 78)
    }

    // Skaliert wie die aura125-Fixture: 241 Positionen -> toParsed bildet 1:1 ab.
    @Test func mapsAll241Positions() throws {
        var rows: [String] = []
        for i in 1...241 {
            rows.append("{\"posNr\": \"\(i).01.01\", \"bezeichnung\": \"Pos \(i)\", \"einheit\": \"m²\", \"menge\": \(Double(i)), \"kg\": null, \"quelle\": \"vision\"}")
        }
        let json = "{\"lv_positionen\": [\(rows.joined(separator: ","))]}"
        let result = try JSONDecoder().decode(ExtractPlanResult.self, from: Data(json.utf8))
        #expect(result.lvPositionen.count == 241)

        let parsed = ExtractPlanMapper.toParsed(result)
        #expect(parsed.count == 241)
        #expect(parsed.allSatisfy { !$0.posNr.isEmpty })
    }

    // Vollständige JSON (alle 4 Felder) dekodiert weiterhin (kein Regress) —
    // Stichprobe wie im Handoff: 14.02.28 PEDOTHERM Heizestrich 60,883 m².
    @Test func decodesFullJSONWithSample() throws {
        let json = """
        {"metadata": {"projekt": "P", "baustelle": "B", "datei": "d.json"},
         "lv_positionen": [{"posNr": "14.02.28", "bezeichnung": "PEDOTHERM Heizestrich", "einheit": "m²", "menge": 60.883, "kg": null, "quelle": "vision"}],
         "bestellliste": [],
         "etiketten": {"hart": [], "geschaetzt": ["14.02.28"]}}
        """
        let result = try JSONDecoder().decode(ExtractPlanResult.self, from: Data(json.utf8))
        let parsed = ExtractPlanMapper.toParsed(result)
        #expect(parsed.count == 1)
        #expect(parsed[0].posNr == "14.02.28")
        #expect(parsed[0].menge == 60.883)
        #expect(parsed[0].einheit == "m²")
    }
}
