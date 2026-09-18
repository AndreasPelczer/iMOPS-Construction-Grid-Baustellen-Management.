//
//  MaterialPreisCheckTests.swift
//  Der Stammdaten-Preis-Check: welche Material der Mops braucht (aus den Baustein-Links)
//  und wo noch DEIN Preis fehlt. In der Bauwelt gibt keiner Preise raus — die einzige
//  ehrliche Quelle ist die eigene Rechnung; dieser Check zeigt die Lücken.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MaterialPreisCheckTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test @MainActor func findetMaterialienDerBausteineMitRichtwert() {
        // Ohne eigene Stammdaten: die verlinkten Materialien (Schotter/Splitt/Schalöl) haben
        // einen Katalog-Richtwert → Status „richtwert" (blau), keiner „eigen".
        let b = MaterialPreisCheck.pruefe(in: ctx)
        #expect(b.gesamt >= 3)
        #expect(b.eigen == 0)
        #expect(b.zeilen.contains { $0.name.contains("Schotter 0/32") })
        #expect(b.zeilen.contains { $0.name.contains("Edelsplitt") })
        // Alle mit Richtwert sind blau, nicht rot (weil die Bausteine einen richtpreis tragen).
        #expect(b.zeilen.allSatisfy { $0.status != .eigen })
    }

    @Test @MainActor func eigenerStammdatenPreisMachtGruen() {
        // Trägst du „Schotter 0/32" mit deinem Preis in die Stammdaten → Status „eigen" (grün),
        // und der günstigste Lieferant gewinnt.
        let m = KalkMaterial(context: ctx)
        m.id = UUID(); m.name = "Schotter 0/32"; m.einheit = "t"
        m.preisProEinheit = 12.5; m.lieferant = "SHB"
        try? ctx.save()

        let b = MaterialPreisCheck.pruefe(in: ctx)
        let schotter = b.zeilen.first { $0.name.contains("Schotter 0/32") }
        #expect(schotter?.status == .eigen)
        #expect(schotter?.eigenerPreis == 12.5)
        #expect(schotter?.lieferant == "SHB")
        #expect(b.eigen >= 1)
    }

    @Test @MainActor func guenstigsterLieferantGewinnt() {
        // Mehrere Lieferanten fürs selbe Material → der günstigste zählt (Preisspiegel).
        for (lief, preis) in [("SHB", 14.0), ("Kieswerk B", 11.9), ("Alt", 16.0)] {
            let m = KalkMaterial(context: ctx)
            m.id = UUID(); m.name = "Edelsplitt 2/5"; m.einheit = "m3"
            m.preisProEinheit = preis; m.lieferant = lief
        }
        try? ctx.save()
        let b = MaterialPreisCheck.pruefe(in: ctx)
        let splitt = b.zeilen.first { $0.name.contains("Edelsplitt") }
        #expect(splitt?.eigenerPreis == 11.9)
        #expect(splitt?.lieferant == "Kieswerk B")
    }
}
