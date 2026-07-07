//
//  KGImportTests.swift
//  DIN-276-KG beim Import heuristisch setzen (statt Sammel-„300").
//  Testet den Helfer ExtractPlanMapper.effektiveKG unabhängig vom Import-Flow.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct KGImportTests {

    @Test func gelieferteKGGewinnt() {
        // Echte KG (Mops/Statik) bleibt unangetastet — Heuristik greift NICHT.
        #expect(ExtractPlanMapper.effektiveKG(kg: "334", bezeichnung: "irgendwas") == "334")
    }

    @Test func nilKGHeuristikGreift() {
        // Bezeichnung mit klarem Keyword → nicht mehr Sammel-300.
        #expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Erdaushub für Gründungspolster") != "300")
        #expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Bodenplattenbeton herstellen") != "300")
        #expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Fenster liefern und einbauen") != "300")
    }

    @Test func nilKGOhneKeywordBleibt300() {
        #expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Blafasel ohne Treffer") == "300")
    }

    @Test func leereKGWirdWieNilBehandelt() {
        // leere/whitespace KG zählt als "nicht geliefert" → Heuristik greift.
        #expect(ExtractPlanMapper.effektiveKG(kg: "", bezeichnung: "Fenster einbauen") != "300")
        #expect(ExtractPlanMapper.effektiveKG(kg: "   ", bezeichnung: "Blafasel") == "300")
    }
}
