//
//  MopsFassTests.swift
//  „Mops fass": der AutoKalkulationsService läuft über ein importiertes LV, matcht jede
//  Position gegen den Leistungskatalog und meldet ehrlich, was fehlt.
//
//  Kern: GRÜN nur bei echtem Preis aus einem Rezept, GELB wenn ein Wert fehlt
//  (Aufwandswert/Material), ROT wenn es gar kein Rezept gibt. Keine erfundene Zahl.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MopsFassTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func position(_ bezeichnung: String, _ einheit: String, menge: Double = 10) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = bezeichnung; pos.einheit = einheit; pos.menge = menge
        return pos
    }

    @Test @MainActor func grueneWennRezeptMitAufwandwert() throws {
        // Vollständiges Rezept (Maurer/Helfer-Stunden) → LVKalkulator liefert einen Preis.
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        let e = AutoKalkulationsService.bewerte(position("Betonwände herstellen", "m²"), in: ctx)
        #expect(e.status == .gruen)
        #expect(e.einheitspreisVK > 0)
    }

    @Test @MainActor func roteWennKeinRezept() throws {
        let e = AutoKalkulationsService.bewerte(position("Dachbegrünung extensiv", "m²"), in: ctx)
        #expect(e.status == .rot)
        #expect(e.einheitspreisVK == 0)
        #expect(e.meldungen.contains { $0.contains("Kein gelerntes Rezept") })
    }

    @Test @MainActor func gelbeWennAufwandwertFehlt() throws {
        // Rezept da, aber ohne Aufwandswert (wie die Tiefbau-Rezepte: Lohn 0 bewusst).
        LeistungskatalogService.merke(leistung: "Oberboden abtragen", einheit: "m³",
                                      maurer: 0, helfer: 0, in: ctx)
        let e = AutoKalkulationsService.bewerte(position("Oberboden abtragen", "m³"), in: ctx)
        #expect(e.status == .gelb)
        #expect(e.meldungen.contains { $0.contains("Aufwandswert") })
    }

    @Test @MainActor func bilanzZaehltAmpelUndExportGate() throws {
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        LeistungskatalogService.merke(leistung: "Oberboden abtragen", einheit: "m³",
                                      maurer: 0, helfer: 0, in: ctx)
        let positionen = [
            position("Betonwände herstellen", "m²"),   // grün
            position("Oberboden abtragen", "m³"),       // gelb
            position("Dachbegrünung extensiv", "m²"),   // rot
        ]
        let ergebnisse = AutoKalkulationsService.fass(positionen: positionen, in: ctx)
        let b = AutoKalkulationsService.bilanz(ergebnisse)
        #expect(b.gruen == 1)
        #expect(b.gelb == 1)
        #expect(b.rot == 1)
        #expect(b.exportBereit == false)   // solange ROT existiert: kein Export
    }

    @Test @MainActor func exportBereitWennKeinRot() throws {
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        let ergebnisse = AutoKalkulationsService.fass(
            positionen: [position("Betonwände herstellen", "m²")], in: ctx)
        #expect(AutoKalkulationsService.bilanz(ergebnisse).exportBereit == true)
    }
}
