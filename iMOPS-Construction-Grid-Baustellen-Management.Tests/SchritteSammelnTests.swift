//
//  SchritteSammelnTests.swift
//
//  "ich muss jetzt aber jeden einzeln anklicken zum übertragen." (Andreas, 22.09.2026)
//
//  Bei 34 Arbeitspaketen sind das 34 Runden. 🔴 Die Reihenfolge ist dabei kein
//  Geschmack: eine Prof-Anfrage darf 180 Sekunden dauern, bei dreissig Aufträgen
//  wären das anderthalb Stunden. Also zuerst alles, was nichts kostet.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct SchritteSammelnTests {

    @discardableResult
    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event, _ name: String,
                         schritte: [String] = [], status: JobStatus = .pending) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = name; a.status = status; a.storageNote = ""; a.event = e
        if !schritte.isEmpty {
            var p = AuftragExtrasPayload()
            p.checklist = schritte.map { AuftragChecklistItem(title: $0) }
            if let d = try? JSONEncoder().encode(p) { a.extras = String(data: d, encoding: .utf8) }
        }
        return a
    }

    private func baustelle() -> (NSManagedObjectContext, Event) {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Sammeln"
        return (ctx, e)
    }

    /// Wer schon Schritte hat, taucht nicht auf — und Erledigte auch nicht.
    @Test func nurWasWirklichFehlt() {
        let (ctx, e) = baustelle()
        auftrag(ctx, e, "Ohne Schritte A")
        auftrag(ctx, e, "Hat schon welche", schritte: ["Schritt 1"])
        auftrag(ctx, e, "Ist fertig", status: .completed)

        let funde = SchritteSammeln.sofort(fuer: e)
        #expect(funde.count == 1)
        #expect(funde.first?.name.contains("Ohne Schritte A") == true)
    }

    /// 🔴 Eine passende Vorlage wird gefunden — aber NICHT vorausgewählt.
    /// Die zwölf Vorlagen sind aus der Anfangszeit und von niemandem abgenommen.
    @Test func ungepruefteVorlagenSindNichtVorausgewaehlt() throws {
        let (ctx, e) = baustelle()
        auftrag(ctx, e, "Pflaster verlegen")

        let f = try #require(SchritteSammeln.sofort(fuer: e).first)
        if f.quelle == .vorlage {
            #expect(!f.uebernehmen, "ungeprüft darf nicht mitrutschen")
            #expect(!f.schritte.isEmpty)
        }
    }

    /// Was gar nichts hergibt, steht als „offen" da — ehrlich statt leer.
    @Test func ohneTrefferStehtOffen() throws {
        let (ctx, e) = baustelle()
        auftrag(ctx, e, "Ein völlig ausgedachter Arbeitsname qwertz")

        let f = try #require(SchritteSammeln.sofort(fuer: e).first)
        #expect(f.quelle == .offen)
        #expect(f.schritte.isEmpty)
        #expect(!f.uebernehmen)
        #expect(f.quelle.kurz.contains("fragen"))
    }

    /// Übernommen wird nur, was angehakt ist.
    @Test func nurAngehaktesWirdUebernommen() throws {
        let (ctx, e) = baustelle()
        let a = auftrag(ctx, e, "Paket A")
        let b = auftrag(ctx, e, "Paket B")
        try ctx.save()

        let funde = [
            SchritteSammeln.Fund(job: a, name: "Paket A", quelle: .katalog,
                                 schritte: [AnweisungsSchritt(text: "Tun", herkunft: .katalog)],
                                 uebernehmen: true),
            SchritteSammeln.Fund(job: b, name: "Paket B", quelle: .vorlage,
                                 schritte: [AnweisungsSchritt(text: "Lassen", herkunft: .vorlage)],
                                 uebernehmen: false),
        ]
        let n = SchritteSammeln.uebernehmen(funde, in: ctx)
        try ctx.save()

        #expect(n == 1)
        #expect(!AuftragExtrasPayload.from(a.extras).checklist.isEmpty)
        #expect(AuftragExtrasPayload.from(b.extras).checklist.isEmpty)
    }

    /// 🔴 Der Sammelweg nimmt NICHTS in den Katalog auf. Der merkt sich nur
    /// Abgenommenes — hier wird übernommen, nicht abgenommen.
    @Test func derKatalogWaechstDabeiNicht() throws {

        let (ctx, e) = baustelle()
        let a = auftrag(ctx, e, "Irgendeine seltsame Arbeit xyz123")
        try ctx.save()

        let vorher = AnweisungsKatalog.shared.schritte(fuer: "Irgendeine seltsame Arbeit xyz123")
        #expect(vorher == nil)

        SchritteSammeln.uebernehmen([
            SchritteSammeln.Fund(job: a, name: "Irgendeine seltsame Arbeit xyz123",
                                 quelle: .vorlage,
                                 schritte: [AnweisungsSchritt(text: "Tun", herkunft: .vorlage)],
                                 uebernehmen: true)], in: ctx)
        try ctx.save()

        #expect(AnweisungsKatalog.shared.schritte(fuer: "Irgendeine seltsame Arbeit xyz123") == nil,
                "ungeprüfte Schritte dürfen sich nicht über alle Baustellen vermehren")
    }
}
