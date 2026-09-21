//
//  VorschlaegeAusBeidenKatalogenTests.swift
//
//  Am 21.09.2026 wurden 1.043 Zeilen aus dem Firmen-Kalkulationskatalog importiert — und
//  beim Tippen von „Streifen" kam trotzdem kein Vorschlag. Grund: die Maske „Neue Position"
//  fragte NUR den STLB-Katalog (YAML, 157 Rezept-Bausteine) ab. Der eigene Katalog liegt
//  aber in Core Data (`Leistungsbaustein`) und wird von `LeistungskatalogService` gelesen.
//  Zwei Töpfe, einer verdrahtet.
//
//  Diese Tests halten fest, dass der eigene Katalog wirklich durchsuchbar ist — er ist der
//  wertvollere von beiden, weil an seinen Zeilen der eigene Preis hängt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct VorschlaegeAusBeidenKatalogenTests {

    private func katalogMit(_ zeilen: [(String, String, Double)]) -> NSManagedObjectContext {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        for (leistung, einheit, preis) in zeilen {
            let b = Leistungsbaustein(context: ctx)
            b.id = UUID(); b.leistung = leistung; b.einheit = einheit
            b.einheitspreisVK = preis; b.quelle = "Goldschmitt-Katalog"
        }
        try? ctx.save()
        // Der Controller muss am Leben bleiben, sonst gibt der Container die Objekte frei.
        objc_setAssociatedObject(ctx, "halten", c, .OBJC_ASSOCIATION_RETAIN)
        return ctx
    }

    /// Der Fall von heute: „Streifen" tippen, Firmenzeilen bekommen.
    @Test func derEigeneKatalogWirdGefunden() {
        let ctx = katalogMit([
            ("Streifenfundamente<B25>d=<80>cm", "m3", 159.32),
            ("Streifenfundamente<B15>d=<40>cm", "m3", 281.63),
            ("Oberboden abtragen Bkl<1-2><>",   "m3", 1.69),
        ])
        let treffer = LeistungskatalogService.vorschlaege(fuer: "Streifen", limit: 8, in: ctx)
        let namen = treffer.compactMap { $0.leistung }
        #expect(namen.contains("Streifenfundamente<B25>d=<80>cm"))
        #expect(namen.contains("Streifenfundamente<B15>d=<40>cm"))
        // Die passenden stehen vorn, nicht irgendwo in der Liste.
        #expect(namen.prefix(2).allSatisfy { $0.lowercased().contains("streifen") })
    }

    /// Der Preis muss mitkommen — er ist der Grund, warum der eigene Katalog zählt.
    @Test func derEigenePreisHaengtDran() throws {
        let ctx = katalogMit([("Streifenfundamente<B25>d=<80>cm", "m3", 159.32)])
        let b = try #require(LeistungskatalogService.vorschlaege(fuer: "Streifenfund",
                                                                limit: 8, in: ctx).first)
        #expect(abs(b.einheitspreisVK - 159.32) < 0.001)
        #expect(b.einheit == "m3")
    }

    /// Goldschmitts Bezeichnungen tragen Parameterfelder wie `<B25>` und `d=<80>cm`.
    /// Die dürfen die Suche nicht stören — sonst findet man die halbe Liste nie.
    @Test func parameterfelderStoerenDieSucheNicht() {
        let ctx = katalogMit([
            ("Mauerwerk<HLZ12><MGII><d=24 cm>", "m3", 412.50),
            ("Baugrubenaushub Bkl<6 ><2,50m>",  "m3", 2.37),
        ])
        #expect(!LeistungskatalogService.vorschlaege(fuer: "Mauerwerk", limit: 8, in: ctx).isEmpty)
        #expect(!LeistungskatalogService.vorschlaege(fuer: "Baugruben", limit: 8, in: ctx).isEmpty)
    }

    /// Der STLB-Katalog (Rezepte) muss weiter funktionieren — beide Listen stehen
    /// nebeneinander, die eine liefert den Preis, die andere das Rezept.
    @Test func derRezeptkatalogFunktioniertWeiter() {
        let treffer = STLBKatalog.shared.vorschlaege(zu: "Mauerwerk Außenwand Ytong")
        #expect(!treffer.isEmpty, "der STLB-Katalog liefert nichts mehr")
    }
}
