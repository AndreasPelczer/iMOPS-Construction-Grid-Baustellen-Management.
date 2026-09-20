//
//  GAEBAnkunftsPruefungTests.swift
//
//  Der Fall vom 20.09.2026, festgenagelt: eine GAEB-Datei bringt 109 Einheitspreise mit,
//  der Import legt 109 Positionen an und meldet „fertig" — im Angebotsspeicher steht
//  nichts. Die Endsumme war dadurch eine andere als die Datei, und gemerkt hat es ein
//  Mensch, dem die Zahl auf dem Bildschirm komisch vorkam.
//
//  Diese Tests halten fest, dass die Prüfung den Unterschied zwischen „geschrieben" und
//  „abrufbar" tatsächlich sieht. Der entscheidende Test ist `preiseInDerDateiAber...`:
//  läuft der grün, obwohl nichts angekommen ist, ist die Prüfung wertlos.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct GAEBAnkunftsPruefungTests {

    /// Baut eine LVPosition im In-Memory-Stack. Der Controller muss FESTGEHALTEN werden
    /// (struct — inline erzeugt gibt der Container die Objekte sofort wieder frei).
    private func position(_ ctx: NSManagedObjectContext,
                          _ posNr: String, _ menge: Double) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = posNr
        p.bezeichnung = "Position \(posNr)"
        p.menge = menge
        p.einheit = "Stk"
        return p
    }

    private func item(_ posNr: String, _ menge: Double, _ up: Double?) -> GAEBImportItem {
        GAEBImportItem(posNr: posNr, kurztext: "Position \(posNr)", langtext: "",
                       menge: menge, einheit: "Stk", unitPrice: up,
                       groupTitle: "", guessedKG: "300", isAlternative: false)
    }

    /// GENAU der Fall von heute: Preise stehen in der Datei, nach dem Speichern ist keiner
    /// abrufbar. Der Bericht muss das als Totalausfall melden und den Fehlbetrag nennen.
    @Test func preiseInDerDateiAberNichtsImAngebotsspeicherIstEinTotalausfall() throws {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let store = AngebotsStore.shared

        let p1 = position(ctx, "543.0010", 19)
        let p2 = position(ctx, "411.0030", 30)
        try ctx.save()   // permanente objectIDs — ohne save() waere der Test selbst falsch
        defer { for p in [p1, p2] {
            store.remove(lieferant: "GAEB-Import", for: p.objectID.uriRepresentation().absoluteString) } }

        // bewusst NICHTS in den Store schreiben: der kaputte Import
        let b = GAEBAnkunftsPruefung.pruefe([(p1, item("543.0010", 19, 452)),
                                             (p2, item("411.0030", 30, 35))])

        #expect(b.positionen == 2)
        #expect(b.preiseInDatei == 2)
        #expect(b.preiseAbrufbar == 0)
        #expect(b.totalausfall)
        #expect(!b.vollstaendig)
        #expect(b.vermisst.count == 2)
        // 19 × 452 + 30 × 35 = 8.588 + 1.050
        #expect(abs(b.summeInDatei - 9638) < 0.001)
        #expect(abs(b.fehlbetrag - 9638) < 0.001)
        // Die teuerste Luecke steht oben — danach schaut man zuerst.
        #expect(b.vermisst.first?.posNr == "543.0010")
    }

    /// Der reparierte Weg: der Preis liegt als Angebot am Schlüssel der permanenten
    /// objectID. Dann ist er abrufbar, und Soll und Ist stimmen überein.
    @Test func angekommenePreiseGeltenAlsAngekommen() throws {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let store = AngebotsStore.shared

        let p = position(ctx, "543.0010", 19)
        try ctx.save()
        let id = p.objectID.uriRepresentation().absoluteString
        defer { store.remove(lieferant: "GAEB-Import", for: id) }
        store.upsert(Angebot(lieferant: "GAEB-Import", einzelpreis: 452), for: id)

        let b = GAEBAnkunftsPruefung.pruefe([(p, item("543.0010", 19, 452))])
        #expect(b.preiseInDatei == 1)
        #expect(b.preiseAbrufbar == 1)
        #expect(b.vollstaendig)
        #expect(!b.totalausfall)
        #expect(abs(b.summeAbrufbar - 8588) < 0.001)
        #expect(b.fehlbetrag == 0)
    }

    /// Eine Datei ohne Preise (DP 83, reine Angebotsaufforderung) darf keinen Alarm
    /// auslösen — da FEHLT nichts, da war nie etwas.
    @Test func ohnePreiseInDerDateiGibtEsNichtsZuVermissen() throws {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let p = position(ctx, "311.0010", 1)
        try ctx.save()

        let b = GAEBAnkunftsPruefung.pruefe([(p, item("311.0010", 1, nil))])
        #expect(b.preiseInDatei == 0)
        #expect(!b.totalausfall)
        #expect(b.vollstaendig)
        #expect(b.ohnePreis == 1)
    }

    /// Teilausfall: einer kommt an, einer nicht. Der Fehlbetrag muss exakt der fehlenden
    /// Position entsprechen — sonst rechnet der Bericht selbst falsch.
    @Test func teilausfallNenntGenauDenFehlbetrag() throws {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        let store = AngebotsStore.shared

        let gut = position(ctx, "543.0010", 19)
        let weg = position(ctx, "543.0020", 10)
        try ctx.save()
        let idGut = gut.objectID.uriRepresentation().absoluteString
        defer {
            store.remove(lieferant: "GAEB-Import", for: idGut)
            store.remove(lieferant: "GAEB-Import", for: weg.objectID.uriRepresentation().absoluteString)
        }
        store.upsert(Angebot(lieferant: "GAEB-Import", einzelpreis: 452), for: idGut)

        let b = GAEBAnkunftsPruefung.pruefe([(gut, item("543.0010", 19, 452)),
                                             (weg, item("543.0020", 10, 560))])
        #expect(b.preiseAbrufbar == 1)
        #expect(b.vermisst.count == 1)
        #expect(b.vermisst.first?.posNr == "543.0020")
        #expect(abs(b.fehlbetrag - 5600) < 0.001)   // 10 × 560
        #expect(!b.totalausfall)                    // einer kam ja an
    }

    /// Der Bestandszähler ist die Grundlage der Doppel-Import-Warnung. Zählt er falsch,
    /// hängt der nächste Import wieder unbemerkt an einen vollen Topf an.
    @Test func bestandZaehltNurDieEigeneBaustelle() throws {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext

        let a = Event(context: ctx)
        let b = Event(context: ctx)
        for nr in ["1", "2", "3"] { position(ctx, nr, 1).event = a }
        position(ctx, "9", 1).event = b
        try ctx.save()

        #expect(GAEBAnkunftsPruefung.bestandVorImport(event: a, in: ctx) == 3)
        #expect(GAEBAnkunftsPruefung.bestandVorImport(event: b, in: ctx) == 1)
    }
}
