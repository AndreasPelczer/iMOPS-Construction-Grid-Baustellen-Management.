//
//  FirmaPreisKatalogTests.swift
//  Beweis: ein importierter Firma-EH-Preis (je Leistung) landet am Leistungsbaustein und
//  wird für eine gleichnamige LV-Position gefunden — Raphis bekannter Preis statt Schätzung.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct FirmaPreisKatalogTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }
    private let importer = StammdatenPreisImportService.shared

    private let csv = """
    typ;name;einheit;preis;lieferant
    leistung;Kelleraußenwand freilegen;m3;80,25;Goldschmitt
    leistung;Mehrsparteneinführung 4-fach;Stück;1784,00;Goldschmitt
    """

    @MainActor
    private func position(_ bez: String, _ einheit: String) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = einheit; p.menge = 5
        return p
    }

    @Test @MainActor
    func importLegtFirmenpreisAmBausteinAn() throws {
        let bericht = importer.importiere(csv: csv, in: ctx)
        #expect(bericht.neuLeistung.count == 2)

        let b = try #require(LeistungskatalogService.finde(
            leistung: "Kelleraußenwand freilegen", einheit: "m3", in: ctx))
        #expect(abs(b.einheitspreisVK - 80.25) < 0.001)
    }

    @Test @MainActor
    func positionFindetFirmenpreis() {
        _ = importer.importiere(csv: csv, in: ctx)
        let pos = position("Kelleraußenwand freilegen", "m3")
        #expect(abs((FirmaPreisKatalog.preis(fuer: pos, in: ctx) ?? 0) - 80.25) < 0.001)
    }

    @Test @MainActor
    func fremdePositionOhneFirmenpreis() {
        _ = importer.importiere(csv: csv, in: ctx)
        let pos = position("Irgendwas Unbekanntes", "m2")
        #expect(FirmaPreisKatalog.preis(fuer: pos, in: ctx) == nil)
    }

    @Test @MainActor
    func reimportVerdoppeltNicht() {
        _ = importer.importiere(csv: csv, in: ctx)
        let zweiter = importer.importiere(csv: csv, in: ctx)
        #expect(zweiter.neuLeistung.isEmpty)
        #expect(zweiter.unveraendertLeistung.count == 2)
    }
}
