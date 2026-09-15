//
//  MaterialPreisZentralTests.swift
//  Der zentrale Material-Preis kommt aus den vorhandenen Stammdaten (KalkMaterial):
//  Menge aus dem Rezept, Preis aus KalkMaterial. Kein Stammdaten-Preis → Rückfall 0.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MaterialPreisZentralTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func stammMaterial(_ name: String, einheit: String, preis: Double) {
        let m = KalkMaterial(context: ctx)
        m.id = UUID(); m.name = name; m.einheit = einheit; m.preisProEinheit = preis
    }

    @Test @MainActor func nachschlagIstNormalisiert() {
        stammMaterial("Beton C20/25", einheit: "m³", preis: 110)
        #expect(LeistungskatalogService.materialPreis(fuer: "Beton C20/25", in: ctx) == 110)
        #expect(LeistungskatalogService.materialPreis(fuer: "  beton c20/25 ", in: ctx) == 110)  // klein/getrimmt
        #expect(LeistungskatalogService.materialPreis(fuer: "Splitt", in: ctx) == nil)
    }

    @Test @MainActor func zentralerPreisGewinntBeimRezeptReplay() throws {
        // Stammdaten-Preis für „Betonpflaster" (Tiefbau-Rezept trägt die Menge, Preis 0)
        stammMaterial("Betonpflaster", einheit: "m²", preis: 18.0)
        _ = TiefbauRezepte.seedIfNeeded(context: ctx)

        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Betonpflaster verlegen"; pos.einheit = "m²"; pos.menge = 120
        #expect(LeistungskatalogService.autoMatch(position: pos, in: ctx))

        let pflaster = try #require(pos.materialArray.first { ($0.materialName ?? "").contains("Betonpflaster") })
        #expect(pflaster.einzelpreis == 18.0)                    // zentraler Preis statt 0
        #expect(LVKalkulator.kalkuliere(position: pos).materialKosten > 0)   // echtes € Material
    }

    @Test @MainActor func ohneStammdatenPreisBleibtRezeptRueckfall() throws {
        _ = TiefbauRezepte.seedIfNeeded(context: ctx)            // keine KalkMaterial-Preise
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Betonpflaster verlegen"; pos.einheit = "m²"; pos.menge = 120
        #expect(LeistungskatalogService.autoMatch(position: pos, in: ctx))
        let pflaster = try #require(pos.materialArray.first { ($0.materialName ?? "").contains("Betonpflaster") })
        #expect(pflaster.einzelpreis == 0)                        // Rückfall auf Rezept-Preis (0)
    }
}
