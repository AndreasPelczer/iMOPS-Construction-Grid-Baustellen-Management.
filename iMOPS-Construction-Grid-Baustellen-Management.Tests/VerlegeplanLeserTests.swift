//
//  VerlegeplanLeserTests.swift
//  Bogen 2: aus einer DXF Mengen ziehen — Maß im Blocknamen, INSERT-Zählung, Aufbau-Layer.
//  Geprüft am echten Muster der Testhofeinfahrt (Pasand-Pflaster, Leistensteine, Schotter/Splitt).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct VerlegeplanLeserTests {

    // Erwartungswerte als explizite Double-Konstanten (hält den Typechecker schnell).
    private let flVoll: Double = 0.39 * 0.195       // 0,076 m²
    private let flHalb: Double = 0.195 * 0.195      // 0,038 m²

    // MARK: Maß aus dem Blocknamen

    @Test func massAusName() {
        // "_" ist Dezimaltrenner, Steinmaß in cm.
        let voll: Double = VerlegeplanLeser.footprintM2(ausName: "Pasand Vollstein_Nr. 59 (Fine)39x19_5x8cm") ?? 0
        #expect(abs(voll - flVoll) < 1e-6)

        let halb: Double = VerlegeplanLeser.footprintM2(ausName: "Pasand Halbstein 19_5x19_5x8cm") ?? 0
        #expect(abs(halb - flHalb) < 1e-6)

        // mm-Suffix wird als mm gelesen.
        let mm: Double = VerlegeplanLeser.footprintM2(ausName: "Platte 600x400x40mm") ?? 0
        let mmErwartet: Double = 0.6 * 0.4
        #expect(abs(mm - mmErwartet) < 1e-6)

        // Kein Maß im Namen → nil (wird gezählt, nicht geraten).
        #expect(VerlegeplanLeser.footprintM2(ausName: "Leistensteine") == nil)
        #expect(VerlegeplanLeser.footprintM2(ausName: "Bordstein Granit") == nil)
    }

    // MARK: INSERT-Zählung + Aggregation

    private func hofDXF(crlf: Bool = false) -> String {
        // 2× Vollstein + 1× Halbstein auf „Pflaster", 1 Block auf „Leistensteine".
        // Rechtsbündige Gruppencodes wie in echten DXF ("  8", " 10").
        let lines = [
            "0", "SECTION", "  2", "TABLES",
            "0", "TABLE", "  2", "LAYER",
            "0", "LAYER", "  2", "Pflaster",
            "0", "LAYER", "  2", "Schotter 0_32",
            "0", "LAYER", "  2", "Splitt 8_16",
            "0", "ENDTAB", "0", "ENDSEC",
            "0", "SECTION", "  2", "ENTITIES",
            "0", "INSERT", "  8", "Pflaster", "  2", "Pasand Vollstein 39x19_5x8cm",
            "0", "INSERT", "  8", "Pflaster", "  2", "Pasand Vollstein 39x19_5x8cm",
            "0", "INSERT", "  8", "Pflaster", "  2", "Pasand Halbstein 19_5x19_5x8cm",
            "0", "INSERT", "  8", "Leistensteine", "  2", "Leistensteine",
            "0", "ENDSEC", "0", "EOF",
        ]
        return lines.joined(separator: crlf ? "\r\n" : "\n")
    }

    @Test func pflasterFlaecheAusZaehlung() {
        let r = VerlegeplanLeser.lies(dxf: hofDXF())
        #expect(!r.istLeer)
        let pflaster = r.layer.first { $0.name == "Pflaster" }
        #expect(pflaster != nil)
        #expect(pflaster?.art == .flaeche)
        #expect(pflaster?.einheit == "m²")
        #expect(pflaster?.objekte == 3)
        // 2×0,076 + 1×0,038 = 0,190 m²
        let ist: Double = pflaster?.menge ?? 0
        let erwartet: Double = 2 * flVoll + flHalb
        #expect(abs(ist - erwartet) < 1e-6)

        // Leistensteine ohne Maß → als Stück, nicht als Fläche.
        let leisten = r.layer.first { $0.name == "Leistensteine" }
        #expect(leisten?.art == .stueck)
        #expect(leisten?.einheit == "St")
        #expect(leisten?.menge == 1)
    }

    @Test func crlfUndRechtsbuendigeCodes() {
        // Echtes DXF-Format (CRLF + "  8"/"  2") muss dasselbe Ergebnis liefern.
        let r = VerlegeplanLeser.lies(dxf: hofDXF(crlf: true))
        let pflaster = r.layer.first { $0.name == "Pflaster" }
        #expect(pflaster?.objekte == 3)
        let ist: Double = pflaster?.menge ?? 0
        let erwartet: Double = 2 * flVoll + flHalb
        #expect(abs(ist - erwartet) < 1e-6)
    }

    // MARK: Aufbau-Layer

    @Test func aufbauLayerAlsHinweis() {
        // Schotter/Splitt sind als Layer definiert, tragen aber keine eigenen Blöcke →
        // als Hinweis (Tragschicht/Bettung), nicht als erfundene Fläche.
        let r = VerlegeplanLeser.lies(dxf: hofDXF())
        #expect(r.layer.first { $0.name == "Schotter 0_32" } == nil)   // keine eigene Position
        #expect(r.hinweise.contains { $0.contains("Schotter 0_32") })
        #expect(r.hinweise.contains { $0.contains("Splitt 8_16") })

        let namen = VerlegeplanLeser.aufbauLayerNamen(hofDXF())
        #expect(namen.contains("Schotter 0_32"))
        #expect(namen.contains("Splitt 8_16"))
    }

    @Test func leererPlan() {
        let r = VerlegeplanLeser.lies(dxf: "0\nSECTION\n  2\nENTITIES\n0\nENDSEC\n0\nEOF\n")
        #expect(r.istLeer)
        #expect(r.hinweise.isEmpty)
    }
}
