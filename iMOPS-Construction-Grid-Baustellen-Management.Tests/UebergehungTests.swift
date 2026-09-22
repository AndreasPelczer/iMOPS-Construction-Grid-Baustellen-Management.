//
//  UebergehungTests.swift
//
//  „Wer ein Nein übergeht, unterschreibt."
//
//  Der wichtigste Test ist `derRiegelWirdGefragt`: bis zum 21.09.2026 hatte
//  `Auftrag.istStartbar` 26 Zusicherungen in den Tests und NULL Aufrufer in der App.
//  Ein Auftrag ließ sich fertig melden, während auf demselben Bildschirm „läuft noch"
//  stand. Getestet war der Riegel — gefragt wurde er nie.
//
//  Deshalb prüfen diese Tests nicht die Rechnung, sondern die VERDRAHTUNG.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct UebergehungTests {

    private func auftrag(_ ctx: NSManagedObjectContext, _ name: String,
                         status: AuftragStatus = .pending) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = name
        a.status = status
        a.storageNote = ""          // Pflichtfeld ohne Default
        return a
    }

    @discardableResult
    private func kante(_ ctx: NSManagedObjectContext, von: Auftrag, zu: Auftrag,
                       name: String? = nil) -> Voraussetzung {
        let v = Voraussetzung(context: ctx)
        v.id = UUID()
        v.name = name
        v.typ = VoraussetzungsTyp.automatisch.rawValue
        v.erfuellt = false
        v.quelle = von
        v.auftrag = zu
        return v
    }

    /// 🔴 DER TEST, DER GEFEHLT HAT: der Riegel trennt startbar von nicht startbar.
    /// Ohne Vorgänger startbar, mit laufendem Vorgänger nicht.
    @Test func derRiegelWirdGefragt() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext

        let schalung = auftrag(ctx, "Schalung stellen", status: .inProgress)
        let beton = auftrag(ctx, "Beton einbringen")
        kante(ctx, von: schalung, zu: beton)
        try ctx.save()

        #expect(schalung.istStartbar, "ohne Vorgänger sofort startbar")
        #expect(!beton.istStartbar, "wartet auf die Schalung")
        #expect(beton.offeneVoraussetzungen.count == 1)

        schalung.status = .completed
        try ctx.save()
        #expect(beton.istStartbar, "Vorgänger fertig — jetzt frei")
        #expect(beton.offeneVoraussetzungen.isEmpty)
    }

    /// Die Übernahme hält fest, WORAUF gewartet wurde — auch wenn die Kante
    /// später gelöst wird. Deshalb Text, nicht Verweis.
    @Test func dieUebernahmeUeberlebtDasLoesenDerKante() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext

        let trocknen = auftrag(ctx, "Estrich trocknen", status: .inProgress)
        let belegen = auftrag(ctx, "Belag verlegen")
        kante(ctx, von: trocknen, zu: belegen)
        try ctx.save()

        let offen = belegen.offeneVoraussetzungen
        #expect(offen.count == 1)

        var extras = AuftragExtrasPayload.from(belegen.extras)
        extras.uebergehungen = [Uebergehung(
            woraufGewartet: offen[0].anzeigename,
            begruendung: "CM-Messung 1,8 % gemessen, belegreif",
            von: "Polier",
            am: Date(),
            offeneVoraussetzungenGesamt: offen.count)]
        belegen.extras = extras.toJSONString()
        try ctx.save()

        // Kante lösen — der Nachweis bleibt
        _ = Kausalkette.entknuepfe(belegen, brauchtNichtMehr: trocknen, in: ctx)
        try ctx.save()

        let danach = AuftragExtrasPayload.from(belegen.extras)
        let u = try #require(danach.uebergehungen?.first)
        #expect(u.woraufGewartet == "Estrich trocknen")
        #expect(u.begruendung == "CM-Messung 1,8 % gemessen, belegreif")
        #expect(belegen.istStartbar, "Kante ist weg — aber der Satz steht noch da")
    }

    /// 🔴 Codable-Falle, richtig herum geprüft: ein Auftrag, der VOR dieser Änderung
    /// geschrieben wurde, kennt `uebergehungen` nicht. Weil das Feld optional ist,
    /// bleibt er lesbar und der Rest kommt heil an.
    @Test func alteAuftraegeBleibenLesbar() throws {
        var vorher = AuftragExtrasPayload()
        vorher.orderNumber = "B-2025-001"
        vorher.persons = 2
        vorher.checklist = [AuftragChecklistItem(title: "Schalung prüfen")]
        let blobOhneNeuesFeld = try #require(vorher.toJSONString())
        #expect(!blobOhneNeuesFeld.contains("uebergehungen"),
                "nil-Felder schreibt der Encoder gar nicht erst")

        let p = AuftragExtrasPayload.from(blobOhneNeuesFeld)
        #expect(p.orderNumber == "B-2025-001")
        #expect(p.persons == 2)
        #expect(p.checklist.count == 1)
        #expect(p.uebergehungen == nil, "fehlendes Feld ist nil, kein Absturz")
    }

    /// 🔴 DIE SCHÄRFERE FALLE, gefunden am 21.09.2026 beim Schreiben des Tests darüber:
    /// `AuftragExtrasPayload.from()` schluckt jeden Dekodier-Fehler und liefert einen
    /// LEEREN Payload zurück. Fehlt auch nur EIN nicht-optionales Feld, ist nicht etwa
    /// dieses Feld leer — es sind ALLE. Checkliste weg, Auftragsnummer weg, still.
    ///
    /// Das heißt: an diesen Payload darf nie ein Pflichtfeld angehängt werden. Der Test
    /// steht hier, damit der Nächste es schwarz auf weiß sieht statt es zu erleben.
    @Test func einFehlendesPflichtfeldMachtDenGanzenBlobLeer() throws {
        // So sähe ein Blob aus, dem ein Pflichtfeld fehlt (z. B. nach einer Erweiterung,
        // die das Feld NICHT optional gemacht hat):
        let lueckenhaft = #"{"trainingMode":true,"orderNumber":"B-2025-001","persons":2}"#
        let p = AuftragExtrasPayload.from(lueckenhaft)

        #expect(p.orderNumber == "", "🔴 nicht nur das fehlende Feld ist weg — alles ist weg")
        #expect(p.persons == 0)
        #expect(p.checklist.isEmpty)
    }

    /// Die Protokollzeile nennt Zeitpunkt, Sache, Person und Grund — in dieser
    /// Reihenfolge, ohne Wertung. Was ein Gutachter in zehn Jahren liest.
    @Test func dieProtokollzeileNenntAllesOhneWertung() throws {
        var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 14; c.hour = 14; c.minute = 20
        let wann = Calendar(identifier: .gregorian).date(from: c)!
        let u = Uebergehung(woraufGewartet: "Estrich trocknen",
                            begruendung: "CM-Messung 1,8 %",
                            von: "Polier", am: wann, offeneVoraussetzungenGesamt: 1)
        let z = u.protokollzeile
        #expect(z.contains("14.03.2026 14:20"))
        #expect(z.contains("Estrich trocknen"))
        #expect(z.contains("Polier"))
        #expect(z.contains("CM-Messung 1,8 %"))
        #expect(!z.lowercased().contains("fehler"))
        #expect(!z.lowercased().contains("verstoß"))
    }

    /// Eine namenlose Kante wird nach ihrem Vorgänger benannt — an EINER Stelle,
    /// damit Tagesblick, Auftragsansicht und Nachweis dasselbe sagen.
    @Test func namenloseKanteHeisstWieIhrVorgaenger() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let vorher = auftrag(ctx, "Bewehrung OG einlegen", status: .inProgress)
        let danach = auftrag(ctx, "Betonage OG")
        let k = kante(ctx, von: vorher, zu: danach, name: nil)
        try ctx.save()

        #expect(k.anzeigename == "Bewehrung OG einlegen")

        k.name = "Bewehrungsabnahme durch Prüfingenieur"
        #expect(k.anzeigename == "Bewehrungsabnahme durch Prüfingenieur",
                "ein eigener Name schlägt den Vorgänger")
    }
}
