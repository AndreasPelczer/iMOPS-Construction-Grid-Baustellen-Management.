//
//  PositionSchnellTests.swift
//
//  Die schlanke Eingabemaske legt an, was drei Masken vorher auf drei Arten taten.
//  Getestet wird nicht die Oberfläche, sondern was am Ende in der Datenbank steht —
//  und ob der Katalog dabei lernt.
//
//  Der wichtigste Test ist `derKatalogLerntDazu`: ohne ihn bleibt der Katalog auf dem
//  Stand des letzten Imports stehen, und jeder tippt dieselbe Leistung wieder von Hand.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct PositionSchnellTests {

    private let TESTQUELLE = "Test-Schnellmaske"

    /// Neu angelegte Leistung landet im Katalog und wird beim nächsten Mal vorgeschlagen.
    @Test func derKatalogLerntDazu() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext

        // Vorher: nichts da
        #expect(LeistungskatalogService.vorschlaege(fuer: "Bohrpfahl", limit: 5, in: ctx).isEmpty)

        let b = LeistungskatalogService.merke(
            leistung: "Bohrpfahl D=60cm setzen", einheit: "m",
            maurer: 0, helfer: 0, kostenGruppeNummer: "322",
            quelle: TESTQUELLE, in: ctx)
        b.einheitspreisVK = 185
        try ctx.save()

        // Nachher: findbar, mit Preis und Kostengruppe
        let treffer = LeistungskatalogService.vorschlaege(fuer: "Bohrpfahl", limit: 5, in: ctx)
        let gefunden = try #require(treffer.first)
        #expect(gefunden.leistung == "Bohrpfahl D=60cm setzen")
        #expect(abs(gefunden.einheitspreisVK - 185) < 0.001)
        #expect(gefunden.kostenGruppeNummer == "322")
    }

    /// Zweimal dieselbe Leistung anlegen darf keinen zweiten Eintrag machen —
    /// sonst wächst der Katalog mit Dubletten zu.
    @Test func zweimalAnlegenGibtKeineDublette() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        for _ in 0..<2 {
            _ = LeistungskatalogService.merke(leistung: "Kernbohrung D=100", einheit: "Stk",
                                              maurer: 0, helfer: 0, quelle: TESTQUELLE, in: ctx)
        }
        try ctx.save()
        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        req.predicate = NSPredicate(format: "leistung == %@", "Kernbohrung D=100")
        #expect(try ctx.count(for: req) == 1)
    }

    /// Der Verwendungszähler sortiert häufige Bausteine nach oben. Er existierte längst,
    /// wurde aber von NIEMANDEM hochgezählt — alle 1.153 Bausteine standen auf 0 und die
    /// Liste war immer alphabetisch. Dieser Test hält fest, dass Zählen wirkt.
    @Test func haeufigBenutztesStehtOben() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let selten = LeistungskatalogService.merke(leistung: "Mauerwerk selten", einheit: "m3",
                                                  maurer: 0, helfer: 0, quelle: TESTQUELLE, in: ctx)
        let oft = LeistungskatalogService.merke(leistung: "Mauerwerk oft", einheit: "m3",
                                                maurer: 0, helfer: 0, quelle: TESTQUELLE, in: ctx)
        _ = selten
        for _ in 0..<5 { LeistungskatalogService.benutzt(oft) }
        try ctx.save()

        let treffer = LeistungskatalogService.vorschlaege(fuer: "Mauerwerk", limit: 5, in: ctx)
        #expect(treffer.first?.leistung == "Mauerwerk oft",
                "der häufiger benutzte Baustein steht nicht oben")
    }

    /// Goldschmitts Katalogzeilen haben KEINE Kostengruppe (die Preisliste kennt nur
    /// Name, Einheit, Preis). Ohne den Textvorschlag landeten alle auf „300" — und damit
    /// im falschen Titel des Angebots.
    @Test func ohneKostengruppeSpringtDerTextvorschlagEin() throws {
        let entwurf = LVDraftPosition(bezeichnung: "Streifenfundamente<B25>d=<80>cm",
                                      einheit: "m3")
        let vorschlag = ExpertValidationService.proposeKG(for: entwurf)
        #expect(vorschlag != nil, "für ein Streifenfundament kommt kein KG-Vorschlag")
        if let v = vorschlag {
            #expect(v.suggestedKG.hasPrefix("3"), "Bauleistung gehört in die 300er-Gruppe")
        }
    }
}
