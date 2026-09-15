//
//  AufwandUebernahmeTests.swift
//  Schließt den Kreis für importierte Positionen: ein Aufwandswert wird auf die Position
//  geschrieben UND ins Rezept gelernt, sodass der nächste gleiche Import ihn automatisch
//  bekommt. Material aus einem vorhandenen Rezept bleibt erhalten.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AufwandUebernahmeTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor private func position(_ bez: String, _ einheit: String) -> LVPosition {
        let p = LVPosition(context: ctx); p.bezeichnung = bez; p.einheit = einheit; p.menge = 100; return p
    }

    @Test @MainActor func aufwandLandetAufPositionUndImRezept() throws {
        let pos = position("Betonpflaster verlegen", "m²")
        LeistungskatalogService.uebernehmeAufwand(maurer: 0.5, helfer: 0.3, quelle: "schätzung", auf: pos, in: ctx)

        // Auf der Position als Lohn geschrieben
        #expect(pos.lohnArray.first { $0.qualifikation == "Maurer" }?.stunden == 0.5)
        #expect(pos.lohnArray.first { $0.qualifikation == "Helfer" }?.stunden == 0.3)

        // Und ins Rezept gelernt (Baustein trägt jetzt den Aufwand + Herkunft)
        let baustein = try #require(LeistungskatalogService.finde(leistung: "Betonpflaster verlegen", einheit: "m²", in: ctx))
        #expect(baustein.maurerStunden == 0.5)
        #expect(baustein.helferStunden == 0.3)
        #expect(baustein.quelle == "schätzung")
    }

    @Test @MainActor func naechsterImportBekommtDenAufwandAutomatisch() throws {
        // Erste Position: Aufwand übernehmen (lernt ins Rezept)
        let erste = position("Trennvlies (Geotextil) verlegen", "m²")
        LeistungskatalogService.uebernehmeAufwand(maurer: 0.1, helfer: 0.1, quelle: "erfahrung", auf: erste, in: ctx)

        // Zweite gleiche Position (wie ein neuer Import) → Auto-Match bringt den Aufwand mit
        let zweite = position("Trennvlies (Geotextil) verlegen", "m²")
        #expect(LeistungskatalogService.autoMatch(position: zweite, in: ctx))
        #expect(zweite.lohnArray.first { $0.qualifikation == "Maurer" }?.stunden == 0.1)
    }

    @Test @MainActor func materialRezeptBleibtBeimAufwandLernenErhalten() throws {
        // Ytong-Rezept (Material) seeden, dann Aufwand drauflernen → Material darf nicht weg
        _ = YtongBedarf.seedIfNeeded(context: ctx)
        let name = YtongBedarf.bausteinName(YtongBedarf.zeile(wanddickeMm: 240)!)
        let pos = position(name, "m³")
        LeistungskatalogService.uebernehmeAufwand(maurer: 2.0, helfer: 1.0, quelle: "schätzung", auf: pos, in: ctx)

        let baustein = try #require(LeistungskatalogService.finde(leistung: name, einheit: "m³", in: ctx))
        #expect(baustein.maurerStunden == 2.0)
        let rezept = try #require(LeistungskatalogService.rezept(von: baustein))   // Material noch da
        #expect(rezept.material.contains { $0.name.contains("Planstein") })
    }
}
