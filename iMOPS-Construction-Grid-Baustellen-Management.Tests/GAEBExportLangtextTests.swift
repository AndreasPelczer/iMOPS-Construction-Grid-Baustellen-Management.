//
//  GAEBExportLangtextTests.swift
//
//  Rein ist nicht raus: am 21.09.2026 kam eine X84 mit 280 Zeichen Langtext je Position
//  herein (Mengenherkunft, Preisquelle, BKI-Nummer) — und wieder heraus kamen 52 Zeichen
//  nackte Bezeichnung. Der Langtext lag die ganze Zeit in der Datenbank, der Export hat
//  ihn nur nie angefasst. Wer so eine Datei weitergibt, gibt die Nachvollziehbarkeit weg,
//  ohne es zu merken.
//
//  GAEB trennt Kurztext (OutlineText) und Langtext (DetailTxt). Diese Tests halten fest,
//  dass beide das Richtige tragen und der Weg rein → raus nichts verliert.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct GAEBExportLangtextTests {

    private func baustelleMit(_ langtext: String?) throws
        -> (PersistenceController, Event, [LVPosition]) {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = Event(context: ctx)
        e.title = "Testbaustelle"
        let p = LVPosition(context: ctx)
        p.posNr = "543.0010"
        p.bezeichnung = "Stützwinkel L 995 B 120 H 1550 liefern und versetzen"
        p.langtext = langtext
        p.menge = 19
        p.einheit = "Stk"
        p.event = e
        try ctx.save()
        return (c, e, [p])
    }

    private func xml(_ e: Event, _ pos: [LVPosition]) -> String {
        String(data: GAEBExporter.export(event: e, positionen: pos, format: .x84_v33),
               encoding: .utf8) ?? ""
    }

    /// Der Langtext gehört in den DetailTxt — vollständig, nicht ersetzt durch die Bezeichnung.
    @Test func derLangtextLandetImDetailtext() throws {
        let voll = "Stützwinkel L 995 B 120 H 1550 liefern und versetzen. Menge 19.00 Stk. "
                 + "Herkunft der Menge: gemessen. Preisquelle: BKI-080000421, 452 EUR je lfm Wand."
        let (c, e, pos) = try baustelleMit(voll)
        _ = c
        let xml = xml(e, pos)
        #expect(xml.contains("Herkunft der Menge: gemessen"),
                "die Mengenherkunft fehlt im Export")
        #expect(xml.contains("BKI-080000421"),
                "die Preisquelle fehlt im Export")
        // Der Kurztext bleibt die Bezeichnung — GAEB trennt die beiden bewusst.
        #expect(xml.contains("<TextComplete>Stützwinkel L 995 B 120 H 1550 liefern und versetzen</TextComplete>"))
    }

    /// Ohne Langtext bleibt es bei der Bezeichnung — kein leerer DetailTxt.
    @Test func ohneLangtextSpringtDieBezeichnungEin() throws {
        let (c, e, pos) = try baustelleMit(nil)
        _ = c
        let xml = xml(e, pos)
        #expect(xml.contains("<span>Stützwinkel L 995 B 120 H 1550 liefern und versetzen</span>"))
        #expect(!xml.contains("<span></span>"))
    }

    /// Die Rundreise: was der eigene Importer aus dem eigenen Export liest, muss der
    /// Langtext sein, mit dem wir reingegangen sind.
    @Test func rundreiseExportDannImportBehaeltDenLangtext() throws {
        let voll = "Zeile eins mit Herkunft\nZeile zwei mit Preisquelle BKI-080000421"
        let (c, e, pos) = try baustelleMit(voll)
        _ = c
        let xml = xml(e, pos)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rundreise-\(UUID().uuidString).x84")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let gelesen = try GAEBImporter.parse(url: url)
        let item = try #require(gelesen.items.first)
        #expect(item.langtext.contains("Herkunft"))
        #expect(item.langtext.contains("BKI-080000421"))
        #expect(item.kurztext == "Stützwinkel L 995 B 120 H 1550 liefern und versetzen")
    }
}
