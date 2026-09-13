//
//  LeistungskatalogTests.swift
//  Bogen 1 — der wachsende Aufwandswert-Katalog. „Einmal fragen, für immer picken."
//
//  Prüft den Service-Vertrag deterministisch (kein Netz, keine UI):
//   - Ernten legt einen Baustein an, Finden holt ihn zurück (case/diakritik-tolerant).
//   - Zweites Ernten derselben Leistung aktualisiert statt zu verdoppeln, Zähler bleibt.
//   - Benutzt zählt hoch (häufige zuerst).
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LeistungskatalogTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    // MARK: - Ernten & Finden

    @Test @MainActor func merkenLegtAnUndFindenHoltZurueck() throws {
        LeistungskatalogService.merke(
            leistung: "Baustelle absichern", einheit: "psch",
            maurer: 0.5, helfer: 1.5, kostenGruppeNummer: "390", quelle: "prof", in: ctx)
        try ctx.save()

        // Exakt
        let treffer = try #require(
            LeistungskatalogService.finde(leistung: "Baustelle absichern", einheit: "psch", in: ctx))
        #expect(treffer.maurerStunden == 0.5)
        #expect(treffer.helferStunden == 1.5)
        #expect(treffer.kostenGruppeNummer == "390")
        #expect(treffer.quelle == "prof")

        // Groß/klein + Diakritik + Leerraum toleriert
        #expect(LeistungskatalogService.finde(leistung: "  BAUSTELLE ABSICHERN ", einheit: "PSCH", in: ctx) != nil)
        // Andere Einheit ist ein anderer Baustein
        #expect(LeistungskatalogService.finde(leistung: "Baustelle absichern", einheit: "m", in: ctx) == nil)
    }

    // MARK: - Kein Doppel, Zähler bleibt

    @Test @MainActor func zweitesMerkenAktualisiertStattZuVerdoppeln() throws {
        LeistungskatalogService.merke(leistung: "Bauzaun stellen", einheit: "m",
                                      maurer: 0.1, helfer: 0.2, in: ctx)
        let ersterTreffer = try #require(
            LeistungskatalogService.finde(leistung: "Bauzaun stellen", einheit: "m", in: ctx))
        LeistungskatalogService.benutzt(ersterTreffer)   // 1 Verwendung
        try ctx.save()

        // Zweites Ernten mit korrigierten Stunden
        LeistungskatalogService.merke(leistung: "Bauzaun stellen", einheit: "m",
                                      maurer: 0.15, helfer: 0.25, in: ctx)
        try ctx.save()

        let alle = LeistungskatalogService.alle(in: ctx)
        #expect(alle.count == 1, "Der Baustein wurde verdoppelt statt aktualisiert.")
        #expect(alle[0].maurerStunden == 0.15)
        #expect(alle[0].helferStunden == 0.25)
        #expect(alle[0].verwendungen == 1, "Der Verwendungszähler ging beim Aktualisieren verloren.")
    }

    // MARK: - Benutzt zählt hoch, Sortierung häufigste zuerst

    @Test @MainActor func benutztZaehltHochUndSortiert() throws {
        LeistungskatalogService.merke(leistung: "Selten", einheit: "St", maurer: 1, helfer: 1, in: ctx)
        let oft = LeistungskatalogService.merke(leistung: "Oft", einheit: "St", maurer: 1, helfer: 1, in: ctx)
        LeistungskatalogService.benutzt(oft)
        LeistungskatalogService.benutzt(oft)
        try ctx.save()

        let alle = LeistungskatalogService.alle(in: ctx)
        #expect(alle.count == 2)
        #expect(alle.first?.leistung == "Oft", "Häufig genutzte Bausteine sollen oben stehen.")
        #expect(alle.first?.verwendungen == 2)
    }

    // MARK: - Vorschlagsliste (die native Auswahl am Knoten)

    @Test @MainActor func vorschlaegeStellenPassendeNachVorn() throws {
        // Ein häufig genutzter, aber UNpassender Baustein …
        let bauzaun = LeistungskatalogService.merke(leistung: "Bauzaun stellen", einheit: "m",
                                                    maurer: 0.1, helfer: 0.2, in: ctx)
        LeistungskatalogService.benutzt(bauzaun)
        LeistungskatalogService.benutzt(bauzaun)   // 2× — stünde sonst oben
        // … und ein passender, nie genutzter.
        LeistungskatalogService.merke(leistung: "Baustelle absichern", einheit: "psch",
                                      maurer: 0.5, helfer: 1.5, in: ctx)
        try ctx.save()

        // Zum Knoten-Text „Baustelle absichern" muss der passende Baustein zuerst kommen,
        // trotz weniger Verwendungen — sonst ist die Liste keine Hilfe.
        let liste = LeistungskatalogService.vorschlaege(fuer: "Baustelle absichern", in: ctx)
        #expect(liste.first?.leistung == "Baustelle absichern")
        #expect(liste.count == 2)

        // Ohne Text: schlicht die häufigsten zuerst.
        let ohne = LeistungskatalogService.vorschlaege(fuer: "", in: ctx)
        #expect(ohne.first?.leistung == "Bauzaun stellen")

        // Das Limit wird eingehalten.
        #expect(LeistungskatalogService.vorschlaege(fuer: "", limit: 1, in: ctx).count == 1)
    }
}
