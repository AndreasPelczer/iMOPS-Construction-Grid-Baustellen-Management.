//
//  TiefbauRezepteTests.swift
//  Prüft die Tiefbau-Rezept-Vorlagen: Mengen/Gerätestunden stimmen, Seeding wird vom
//  Auto-Match gefunden, Lohn bleibt bewusst 0 (Aufwandswert offen), idempotent.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct TiefbauRezepteTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test func vorlagenSindWohlgeformt() {
        #expect(!TiefbauRezepte.vorlagen.isEmpty)
        for v in TiefbauRezepte.vorlagen {
            #expect(!v.leistung.isEmpty)
            #expect(!v.einheit.isEmpty)
            // Jede Vorlage trägt entweder Material oder Gerät (sonst wäre sie leer)
            #expect(!v.material.isEmpty || !v.geraet.isEmpty)
            #expect(v.material.allSatisfy { $0.menge > 0 })
        }
    }

    @Test func baggerStundenKommenAusErdbauleistung() {
        let aushub = TiefbauRezepte.vorlagen.first { $0.leistung.contains("Aushub") }!
        let bagger = aushub.geraet.first { $0.name.contains("Minibagger") }
        // 1 m³ ÷ 4,4 m³/h ≈ 0,2273 h
        #expect(abs((bagger?.stundenProEinheit ?? 0) - (1.0 / 4.4)) < 0.0001)
    }

    @Test func pflasterUndTrennvliesHabenRichtwertMengen() {
        let pflaster = TiefbauRezepte.vorlagen.first { $0.leistung.contains("Betonpflaster") }!
        let stein = TiefbauRezepte.rezept(pflaster).material.first!
        #expect(stein.mengeProEinheit == 1.0)
        #expect(stein.verschnittProzent == 0.02)          // 2 % Verschnitt
        let vlies = TiefbauRezepte.vorlagen.first { $0.leistung.contains("Trennvlies") }!
        #expect(TiefbauRezepte.rezept(vlies).material.first?.mengeProEinheit == 1.1)  // 10 % Überlappung
    }

    @Test @MainActor func seedingWirdVomAutoMatchGefundenLohnBleibtOffen() throws {
        let n = TiefbauRezepte.seedIfNeeded(context: ctx)
        #expect(n == TiefbauRezepte.vorlagen.count)

        // Import: „Betonpflaster verlegen" (m²) → Material kommt, aber KEIN Preis (Lohn 0)
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Betonpflaster verlegen"
        pos.einheit = "m²"
        pos.menge = 120
        #expect(LeistungskatalogService.autoMatch(position: pos, in: ctx))
        #expect(pos.materialArray.contains { ($0.materialName ?? "").contains("Betonpflaster") })
        #expect(pos.lohnArray.allSatisfy { $0.stunden == 0 })   // Aufwandswert noch offen
        // Ohne Preise ergibt sich (noch) kein Positionspreis — ehrlich, keine erfundene Zahl
        let kalk = LVKalkulator.kalkuliere(position: pos)
        #expect(kalk.gesamtpreis == 0)
    }

    @Test @MainActor func seedingIstIdempotent() throws {
        _ = TiefbauRezepte.seedIfNeeded(context: ctx)
        _ = TiefbauRezepte.seedIfNeeded(context: ctx)
        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        req.predicate = NSPredicate(format: "leistung == %@", "Betonpflaster verlegen")
        #expect((try ctx.fetch(req)).count == 1)              // kein Doppel
    }
}
