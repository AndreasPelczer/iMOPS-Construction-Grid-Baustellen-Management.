//
//  ExtractPlanMapperTests.swift
//  Welle 4 / Scheibe 2 — Mapping /extract-plan JSON → CoreData LVPosition
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ExtractPlanMapperTests {

    // In-Memory-Stack dauerhaft halten (struct → inline würde freigegeben).
    @MainActor private static let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { Self.controller.container.viewContext }

    // Realistischer Ausschnitt einer /extract-plan-Antwort: eine Wand MIT
    // Bestellzeile (Mat-Nr), eine Stahlbeton-Position OHNE Bestellzeile.
    private let sampleJSON = """
    {
      "metadata": {"projekt": "I-25_448-GO", "baustelle": "Marktbreit", "datei": "statik.pdf"},
      "waende": [], "bewehrung": [],
      "lv_positionen": [
        {"posNr": "3.30.1", "kg": "330", "bezeichnung": "Außenwand Porenbeton Z-17.1-543, d=36,5 cm", "einheit": "m²", "menge": 28.42, "quelle": "statik_tabelle"},
        {"posNr": "3.30.4", "kg": "330", "bezeichnung": "Stahlbetonstütze 16/30 cm", "einheit": "Stk", "menge": 4, "quelle": "statik_tabelle"}
      ],
      "bestellliste": [
        {"artikel": "Porenbeton Z-17.1-543 d=36,5 cm", "matnr": "10005024", "produkt": "PPW 4-0,50 NF-GT", "konfidenz": "hoch", "mat_hinweis": "exakt", "freigabe": null, "lieferant": "Xella", "paletten": 8, "steine": 183, "flaeche_m2": 28.42, "bezug_posNr": "3.30.1", "quelle": "statik_tabelle"}
      ],
      "etiketten": {"hart": ["3.30.1", "3.30.4"], "geschaetzt": []}
    }
    """

    @MainActor
    private func decoded() throws -> ExtractPlanResult {
        try JSONDecoder().decode(ExtractPlanResult.self, from: Data(sampleJSON.utf8))
    }

    @MainActor
    @Test func decodesBoxResponse() throws {
        let r = try decoded()
        #expect(r.lvPositionen.count == 2)
        #expect(r.bestellliste.count == 1)
        #expect(r.metadata.projekt == "I-25_448-GO")
        #expect(r.bestellliste.first?.matnr == "10005024")
        #expect(r.bestellliste.first?.bezugPosNr == "3.30.1")
    }

    @MainActor
    @Test func mapsCoreFieldsAndLinksBestellliste() throws {
        let positions = ExtractPlanMapper.mapPositions(try decoded(), into: ctx)
        #expect(positions.count == 2)

        let wand = try #require(positions.first { $0.posNr == "3.30.1" })
        #expect(wand.kostenGruppeNummer == "330")
        #expect(wand.einheit == "m²")
        #expect(wand.menge == 28.42)
        // Bestellzeile via bezug_posNr verknüpft → Mat-Nr + Lieferant gesetzt
        #expect(wand.artikelNummer == "10005024")
        #expect(wand.lieferant == "Xella")
    }

    @MainActor
    @Test func positionOhneBestellzeileBleibtOhneMatNr() throws {
        let positions = ExtractPlanMapper.mapPositions(try decoded(), into: ctx)
        let stuetze = try #require(positions.first { $0.posNr == "3.30.4" })
        #expect(stuetze.bezeichnung == "Stahlbetonstütze 16/30 cm")
        #expect(stuetze.artikelNummer == nil)   // keine passende Bestellzeile
    }

    @MainActor
    @Test func haengtAnEventWennGegeben() throws {
        let event = Event(context: ctx)
        event.title = "Test-Baustelle"
        event.eventNumber = "TEST-001"
        let positions = ExtractPlanMapper.mapPositions(try decoded(), into: ctx, event: event)
        #expect(positions.allSatisfy { $0.event === event })
    }

    @MainActor
    @Test func toParsedTraegtKgMatNrUndConfidence() throws {
        let parsed = ExtractPlanMapper.toParsed(try decoded())
        #expect(parsed.count == 2)

        let wand = try #require(parsed.first { $0.posNr == "3.30.1" })
        #expect(wand.kostenGruppe == "330")
        #expect(wand.artikelNummer == "10005024")
        #expect(wand.lieferant == "Xella")
        #expect(wand.confidence > 0.8)   // statik_tabelle → hoch
        #expect(wand.isSelected)         // standardmäßig ausgewählt

        // Stahlbeton-Position ohne Bestellzeile: KG da, aber keine Mat-Nr
        let stuetze = try #require(parsed.first { $0.posNr == "3.30.4" })
        #expect(stuetze.kostenGruppe == "330")
        #expect(stuetze.artikelNummer == nil)
    }

    @MainActor
    @Test func mengeNullCrashtNicht() throws {
        // "manuell"-Positionen (Streifenfundament, Ringbalken) liefern menge=null —
        // darf NICHT zu einem Decode-Fehler führen (Regression aus dem Live-Demo).
        let json = """
        {"metadata": {}, "waende": [], "bewehrung": [],
         "lv_positionen": [
           {"posNr": "3.20.2", "kg": "320", "bezeichnung": "Streifenfundament", "einheit": "m", "menge": null, "quelle": "manuell"}
         ],
         "bestellliste": [], "etiketten": {"hart": [], "geschaetzt": []}}
        """
        let r = try JSONDecoder().decode(ExtractPlanResult.self, from: Data(json.utf8))
        #expect(r.lvPositionen.first?.menge == nil)
        #expect(ExtractPlanMapper.toParsed(r).first?.menge == 0)        // nil → 0
        #expect(ExtractPlanMapper.mapPositions(r, into: ctx).first?.menge == 0)
    }
}
