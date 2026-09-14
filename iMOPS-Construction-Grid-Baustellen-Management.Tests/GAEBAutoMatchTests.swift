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

    // MARK: - Lücke 2: volles Rezept (Lohn + Material + Gerät)

    @Test @MainActor func rezeptMitMaterialUndGeraetWirdMitkalkuliert() throws {
        // Quelle: eine fertig kalkulierte Position mit Lohn + Material + Gerät.
        let quelle = position("Betonsohle herstellen", "m²", menge: 800)
        LeistungskatalogService.schreibeAufwandAlsLohn(maurer: 0.3, helfer: 0.2, auf: quelle, in: ctx)
        let pm = PositionMaterial(context: ctx)
        pm.id = UUID(); pm.materialName = "Beton C20/25"; pm.mengeProEinheit = 0.12
        pm.einzelpreis = 110; pm.verschnittProzent = 0.05; pm.einheit = "m³"; pm.position = quelle
        let pg = PositionGeraet(context: ctx)
        pg.id = UUID(); pg.geraetName = "Rüttelplatte"; pg.stunden = 0.05; pg.kostenProStunde = 30; pg.position = quelle

        // Rezept lernen (Lohn via merke, Material/Gerät via lerneMaterialUndGeraet).
        let baustein = LeistungskatalogService.merke(
            leistung: "Betonsohle herstellen", einheit: "m²", maurer: 0.3, helfer: 0.2, in: ctx)
        LeistungskatalogService.lerneMaterialUndGeraet(von: quelle, auf: baustein)
        #expect(baustein.rezeptJSON != nil)

        // Ziel: frische Position → autoMatch schreibt Lohn + Material + Gerät.
        let ziel = position("Betonsohle herstellen", "m²", menge: 800)
        #expect(LeistungskatalogService.autoMatch(position: ziel, in: ctx))
        #expect(ziel.materialArray.count == 1)
        #expect(ziel.geraeteArray.count == 1)
        #expect(ziel.lohnArray.count == 2)

        let kalk = LVKalkulator.kalkuliere(position: ziel)
        #expect(kalk.materialKosten > 0)
        #expect(kalk.geraeteKosten > 0)
        #expect(kalk.lohnKosten > 0)
    }

    @Test @MainActor func autoMatchIstIdempotentKeinMaterialStapeln() throws {
        let quelle = position("Betonsohle herstellen", "m²", menge: 800)
        let pm = PositionMaterial(context: ctx)
        pm.id = UUID(); pm.materialName = "Beton"; pm.mengeProEinheit = 0.12
        pm.einzelpreis = 110; pm.verschnittProzent = 0; pm.einheit = "m³"; pm.position = quelle
        let baustein = LeistungskatalogService.merke(
            leistung: "Betonsohle herstellen", einheit: "m²", maurer: 0.3, helfer: 0.2, in: ctx)
        LeistungskatalogService.lerneMaterialUndGeraet(von: quelle, auf: baustein)

        let ziel = position("Betonsohle herstellen", "m²", menge: 800)
        _ = LeistungskatalogService.autoMatch(position: ziel, in: ctx)
        _ = LeistungskatalogService.autoMatch(position: ziel, in: ctx)   // zweimal
        #expect(ziel.materialArray.count == 1)                           // nicht gestapelt
        #expect(ziel.lohnArray.count == 2)
    }
}
