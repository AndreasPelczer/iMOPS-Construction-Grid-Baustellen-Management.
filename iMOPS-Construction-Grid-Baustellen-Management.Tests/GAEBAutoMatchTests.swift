//
//  GAEBAutoMatchTests.swift
//  Belegt den Auto-Match beim Import: eine importierte Position (Bezeichnung + Einheit)
//  findet ihr gelerntes Rezept im Leistungskatalog und bekommt darüber einen Preis
//  (LVKalkulator). Kein Treffer = KEIN Preis (keine erfundene Zahl) — die ehrliche
//  Voreinstellung.
//
//  „Erst messen, dann behaupten": der Preis entsteht durch das Rezept, nicht durch Ansage.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct GAEBAutoMatchTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Legt eine Position wie beim GAEB-Import an (nur Bezeichnung/Einheit/Menge).
    @MainActor
    private func position(_ bezeichnung: String, _ einheit: String, menge: Double) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = bezeichnung
        pos.einheit = einheit
        pos.menge = menge
        return pos
    }

    @Test @MainActor func trefferSchreibtAufwandUndErgibtPreis() throws {
        // Rezept lernen (wie aus Prof/Katalog).
        LeistungskatalogService.merke(
            leistung: "Betonwände herstellen", einheit: "m²",
            maurer: 0.8, helfer: 0.4, kostenGruppeNummer: "330", quelle: "prof", in: ctx)

        let pos = position("Betonwände herstellen", "m²", menge: 240)
        let treffer = LeistungskatalogService.autoMatch(position: pos, in: ctx)

        #expect(treffer)                                   // Match gefunden
        // Aufwand als Lohn geschrieben (Maurer + Helfer)
        let quals = Set(pos.lohnArray.map { $0.qualifikation })
        #expect(quals.contains("Maurer"))
        #expect(quals.contains("Helfer"))
        #expect(pos.lohnArray.first { $0.qualifikation == "Maurer" }?.stunden == 0.8)
        // KG aus dem Rezept übernommen (Position hatte keine)
        #expect(pos.kostenGruppeNummer == "330")
        // Und daraus rechnet der LVKalkulator einen Preis > 0
        let kalk = LVKalkulator.kalkuliere(position: pos)
        #expect(kalk.gesamtpreis > 0)
    }

    @Test @MainActor func matchIstDiakritikUndGrossKleinTolerant() throws {
        LeistungskatalogService.merke(
            leistung: "Betonwände herstellen", einheit: "m²",
            maurer: 0.8, helfer: 0.4, in: ctx)
        // andere Schreibweise (klein, extra Leerraum) trifft trotzdem
        let pos = position("  betonwande herstellen ", "m²", menge: 10)
        #expect(LeistungskatalogService.autoMatch(position: pos, in: ctx))
    }

    @Test @MainActor func keinTrefferBleibtOhnePreis() throws {
        LeistungskatalogService.merke(
            leistung: "Betonwände herstellen", einheit: "m²",
            maurer: 0.8, helfer: 0.4, in: ctx)

        // Position, für die es kein Rezept gibt
        let pos = position("Dachbegrünung extensiv", "m²", menge: 50)
        let treffer = LeistungskatalogService.autoMatch(position: pos, in: ctx)

        #expect(!treffer)                                  // kein Match
        #expect(pos.lohnArray.isEmpty)                     // kein Aufwand geschrieben
        let kalk = LVKalkulator.kalkuliere(position: pos)
        #expect(kalk.gesamtpreis == 0)                     // KEINE erfundene Zahl
    }

    @Test @MainActor func falscheEinheitIstKeinTreffer() throws {
        LeistungskatalogService.merke(
            leistung: "Verfüllen der Baugrube", einheit: "m³",
            maurer: 0.2, helfer: 0.3, in: ctx)
        // gleiche Leistung, aber Einheit m² statt m³ → bewusst kein Treffer
        let pos = position("Verfüllen der Baugrube", "m²", menge: 600)
        #expect(!LeistungskatalogService.autoMatch(position: pos, in: ctx))
    }
}
