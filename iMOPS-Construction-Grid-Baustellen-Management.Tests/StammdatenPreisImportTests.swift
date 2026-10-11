//
//  StammdatenPreisImportTests.swift
//  Der Nachweis: eine Preis-CSV landet WIRKLICH in den Stammdaten — und ein
//  Re-Import verdoppelt nicht. Genau die Sicherung, die bisher fehlte
//  (Preise lagen wochenlang "eingebaut", waren es aber nie).
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct StammdatenPreisImportTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    private let service = StammdatenPreisImportService.shared

    private let csv = """
    typ;name;einheit;preis;lieferant
    material;Beton C25/30;m3;130,00;Transportbeton (Markt)
    material;Betonstahl B500A;kg;1,20;Markt
    lohn;Eisenflechter;h;47,00;
    """

    @MainActor
    private func material(_ name: String) throws -> KalkMaterial {
        let r: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
        r.predicate = NSPredicate(format: "name == %@", name)
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func lohn(_ name: String) throws -> Lohnsatz {
        let r: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        r.predicate = NSPredicate(format: "qualifikation == %@", name)
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func geraet(_ name: String) throws -> Geraet {
        let r: NSFetchRequest<Geraet> = Geraet.fetchRequest()
        r.predicate = NSPredicate(format: "name == %@", name)
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func anzahl<T: NSManagedObject>(_ typ: T.Type, _ entity: String) throws -> Int {
        try ctx.count(for: NSFetchRequest<T>(entityName: entity))
    }

    // MARK: - Der Beweis: die Zeilen landen

    @Test @MainActor
    func importLegtMaterialUndLohnAn() throws {
        let bericht = service.importiere(csv: csv, in: ctx)

        #expect(bericht.neuMaterial.count == 2)
        #expect(bericht.neuLohn.count == 1)
        #expect(bericht.uebersprungen.isEmpty)

        // Wirklich in Core Data — nicht nur im Bericht behauptet.
        #expect(try anzahl(KalkMaterial.self, "KalkMaterial") == 2)
        #expect(try anzahl(Lohnsatz.self, "Lohnsatz") == 1)

        #expect(abs(try material("Beton C25/30").preisProEinheit - 130.0) < 0.001)
        #expect(try material("Beton C25/30").einheit == "m3")
        #expect(try material("Beton C25/30").lieferant == "Transportbeton (Markt)")
        #expect(abs(try material("Betonstahl B500A").preisProEinheit - 1.20) < 0.001)
        // Lohn: Brutto-EK = stundenlohn × zuschlagFaktor(1,0)
        #expect(abs(try lohn("Eisenflechter").berechnungBruttoEK - 47.0) < 0.001)
    }

    @Test @MainActor
    func reimportVerdoppeltNicht() throws {
        _ = service.importiere(csv: csv, in: ctx)
        let zweiter = service.importiere(csv: csv, in: ctx)

        // Zweiter Lauf: nichts Neues, alles unverändert — und keine Dubletten.
        #expect(zweiter.neuMaterial.isEmpty)
        #expect(zweiter.neuLohn.isEmpty)
        #expect(zweiter.unveraendertMaterial.count == 2)
        #expect(zweiter.unveraendertLohn.count == 1)
        #expect(try anzahl(KalkMaterial.self, "KalkMaterial") == 2)
        #expect(try anzahl(Lohnsatz.self, "Lohnsatz") == 1)
    }

    @Test @MainActor
    func preisAenderungWirdAktualisiert() throws {
        _ = service.importiere(csv: csv, in: ctx)
        let geaendert = service.importiere(
            csv: "material;Beton C25/30;m3;135,50;Neuer Preis", in: ctx)

        #expect(geaendert.aktualisiertMaterial.count == 1)
        let a = try #require(geaendert.aktualisiertMaterial.first)
        #expect(abs(a.alt - 130.0) < 0.001)
        #expect(abs(a.neu - 135.50) < 0.001)
        // Persistiert, nicht verdoppelt.
        #expect(try anzahl(KalkMaterial.self, "KalkMaterial") == 2)
        #expect(abs(try material("Beton C25/30").preisProEinheit - 135.50) < 0.001)
    }

    // MARK: - Gerät: fester Std-Satz landet in der Auswahlliste

    @Test @MainActor
    func importLegtGeraetMitStundensatzAn() throws {
        let bericht = service.importiere(
            csv: "geraet;Bagger 9to;Std;45,60;Firma-Katalog", in: ctx)

        #expect(bericht.neuGeraet.count == 1)
        #expect(bericht.uebersprungen.isEmpty)
        #expect(try anzahl(Geraet.self, "Geraet") == 1)

        let g = try geraet("Bagger 9to")
        #expect(abs(g.stundensatz - 45.60) < 0.001)
        // Der feste Satz treibt kostenProStunde direkt (nicht die Abschreibung).
        #expect(abs(g.kostenProStunde - 45.60) < 0.001)
    }

    @Test @MainActor
    func geraetReimportAendertNichtUndVerdoppeltNicht() throws {
        let csvG = "geraet;Minibagger;Std;37,20;Firma-Katalog"
        _ = service.importiere(csv: csvG, in: ctx)
        let zweiter = service.importiere(csv: csvG, in: ctx)
        #expect(zweiter.neuGeraet.isEmpty)
        #expect(zweiter.unveraendertGeraet.count == 1)
        #expect(try anzahl(Geraet.self, "Geraet") == 1)

        // Satz geändert -> aktualisiert, nicht verdoppelt.
        let geaendert = service.importiere(csv: "geraet;Minibagger;Std;39,00;neu", in: ctx)
        #expect(geaendert.aktualisiertGeraet.count == 1)
        #expect(abs(try geraet("Minibagger").stundensatz - 39.00) < 0.001)
        #expect(try anzahl(Geraet.self, "Geraet") == 1)
    }

    @Test @MainActor
    func kaputteZeileWirdUebersprungenNichtVerschluckt() throws {
        let bericht = service.importiere(
            csv: "material;Ohne Preis;m2;;Markt\nmaterial;Gut;m3;99,00;Markt", in: ctx)
        #expect(bericht.neuMaterial.count == 1)          // die gute landet
        #expect(bericht.uebersprungen.count == 1)        // die kaputte wird GEMELDET
        #expect(try anzahl(KalkMaterial.self, "KalkMaterial") == 1)
    }

    // MARK: - Erst zeigen, dann speichern (10.10.2026)

    @Test @MainActor
    func vorschauAendertNichts() throws {
        let b = service.vorschau(csv: csv, in: ctx)
        #expect(b.istVorschau && b.landetGesamt == 3 && b.quelleText == csv)
        #expect(try anzahl(KalkMaterial.self, "KalkMaterial") == 0)   // nichts angelegt
        #expect(try anzahl(Lohnsatz.self, "Lohnsatz") == 0)
        #expect(!ctx.hasChanges)                                       // auch nicht ungespeichert im Kontext
    }

    @Test @MainActor
    func vorschauZeigtAltNeuOhneZuAendern() throws {
        _ = service.importiere(csv: csv, in: ctx)
        let neu = csv.replacingOccurrences(of: "130,00", with: "1300,00")   // der Komma-Fehler
        let b = service.vorschau(csv: neu, in: ctx)
        let a = try #require(b.aktualisiertMaterial.first)
        #expect(a.alt == 130 && a.neu == 1300 && a.auffaellig && a.prozent == 900)
        #expect(try material("Beton C25/30").preisProEinheit == 130)    // Stammdaten unberührt
    }

    @Test @MainActor
    func uebernehmenSpeichertWirklich() throws {
        let b = service.vorschau(csv: csv, in: ctx)
        _ = service.importiere(csv: b.quelleText ?? "", in: ctx)
        #expect(try material("Beton C25/30").preisProEinheit == 130)
        #expect(!ctx.hasChanges)
    }

    @Test func kleinerSprungIstNichtAuffaellig() {
        #expect(!PreisImportBericht.Aenderung(name: "x", alt: 12.40, neu: 13.10, einheit: "Stk").auffaellig)
    }
}

// MARK: - Riegel 11.10.2026: fremdes Format wird nicht still als Material übernommen

struct PreisImportFremdesFormatTests {
    private let controller = PersistenceController(inMemory: true)

    /// Aufbau wie eine Recycling-Liste (Kategorie;Material;Körnung;…) – Werte erfunden.
    private let fremd = """
    Kategorie;Material;Koernung;Listenpreis;Firmenpreis;Einheit
    Recycling;RC-Schotter;0/16;9,00;7,00;t
    Recycling;RC-Schotter;0/32;8,00;6,00;t
    """

    @Test @MainActor
    func unbekannterTypWirdNichtUebernommen() {
        let ctx = controller.container.viewContext
        let b = StammdatenPreisImportService.shared.vorschau(csv: fremd, in: ctx)
        #expect(b.landetGesamt == 0)          // keine „0/16“-Einheit in den Stammdaten
        #expect(b.fremdesFormat == 3)         // Kopfzeile zählt mit – sie ist keine erkannte Kopfzeile
        #expect(b.uebersprungen.contains { $0.contains("unbekannter Typ") })
    }

    @Test @MainActor
    func leererTypBleibtMaterial() {
        let ctx = controller.container.viewContext
        let b = StammdatenPreisImportService.shared.vorschau(csv: ";Kantenschutz;m;2,50;Markt", in: ctx)
        #expect(b.neuMaterial == ["Kantenschutz"] && b.fremdesFormat == 0)
    }
}
