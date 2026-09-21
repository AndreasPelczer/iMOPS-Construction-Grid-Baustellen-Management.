//
//  FirmaTransferLeistungenTests.swift
//
//  „Die Firma" aufs andere Gerät bringen hieß bisher: Materialien, Löhne, Geräte,
//  Firmensettings. Der LEISTUNGSKATALOG blieb zurück — also genau der Topf, aus dem die
//  Vorschläge beim Tippen kommen. Wer die Datei importierte, bekam Materialpreise, aber
//  beim Anlegen einer Position immer noch eine leere Liste.
//
//  Der zweite Test ist der wichtigere: eine .mopsfirma AUS DER ZEIT VOR diesem Feld muss
//  weiter lesbar sein. Swifts synthetisiertes Decodable wirft bei einem fehlenden Key
//  keyNotFound — auch wenn das Feld einen Default-Wert hat. Deshalb ist `leistungen`
//  optional. Dieselbe Falle wie damals beim EventExtrasPayload.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct FirmaTransferLeistungenTests {

    @Test func derLeistungskatalogFaehrtMit() throws {
        let quelle = PersistenceController(inMemory: true)
        let qctx = quelle.container.viewContext
        let b = Leistungsbaustein(context: qctx)
        b.id = UUID()
        b.leistung = "Streifenfundamente<B25>d=<80>cm"
        b.einheit = "m3"
        b.einheitspreisVK = 159.32
        b.maurerStunden = 1.2
        b.helferStunden = 0.8
        b.kostenGruppeNummer = "322"
        b.quelle = "Goldschmitt-Katalog"
        try qctx.save()

        let daten = try FirmaTransfer.exportieren(in: qctx)

        let ziel = PersistenceController(inMemory: true)
        let zctx = ziel.container.viewContext
        let bilanz = try FirmaTransfer.importieren(daten, in: zctx)

        #expect(bilanz.leistungen == 1)
        let angekommen = try #require(
            LeistungskatalogService.finde(leistung: "Streifenfundamente<B25>d=<80>cm",
                                          einheit: "m3", in: zctx))
        #expect(abs(angekommen.einheitspreisVK - 159.32) < 0.001)
        #expect(angekommen.kostenGruppeNummer == "322")
        #expect(abs(angekommen.maurerStunden - 1.2) < 0.001)
    }

    /// Eine Datei von VOR dieser Änderung kennt den Schlüssel `leistungen` nicht.
    /// Sie muss trotzdem importierbar bleiben — sonst kann nach einem Update niemand
    /// mehr eine ältere Firma-Datei einlesen.
    @Test func alteDateiOhneLeistungenBleibtLesbar() throws {
        let alt = """
        {"version":1,"exportiert":"2026-06-01T10:00:00Z",
         "texte":{"firma_name":"Testfirma"},"zahlen":{},"flags":{},
         "materialien":[],"loehne":[],"geraete":[]}
        """
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let bilanz = try FirmaTransfer.importieren(Data(alt.utf8), in: ctx)
        #expect(bilanz.leistungen == 0)
        #expect(bilanz.settings == 1)
    }

    /// Zweimal importieren darf nicht doppeln — der Katalog wird über die id abgeglichen.
    @Test func zweimalImportierenDoppeltNicht() throws {
        let quelle = PersistenceController(inMemory: true)
        let qctx = quelle.container.viewContext
        let b = Leistungsbaustein(context: qctx)
        b.id = UUID(); b.leistung = "Oberboden abtragen Bkl<1-2><>"; b.einheit = "m3"
        b.einheitspreisVK = 1.69
        try qctx.save()
        let daten = try FirmaTransfer.exportieren(in: qctx)

        let ziel = PersistenceController(inMemory: true)
        let zctx = ziel.container.viewContext
        _ = try FirmaTransfer.importieren(daten, in: zctx)
        _ = try FirmaTransfer.importieren(daten, in: zctx)

        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        #expect(try zctx.count(for: req) == 1)
    }
}
