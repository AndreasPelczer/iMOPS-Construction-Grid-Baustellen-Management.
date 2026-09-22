//
//  BaustelleLoeschenTests.swift
//
//  "Aber das löschen war falsch. Wie lösche ich eine Baustelle richtig damit nichts
//   verwaist?" (Andreas, 22.09.2026)
//
//  🔴 Die ehrliche Antwort war: gar nicht. `Event.jobs` steht im Modell auf Nullify,
//  also blieb bei JEDEM Löschen jeder Auftrag zurück. Kein Bedienfehler — ein
//  Konstruktionsfehler. Diese Tests halten fest, dass er behoben ist.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct BaustelleLoeschenTests {

    private func baustelleMitAllem(_ ctx: NSManagedObjectContext) -> Event {
        let e = Event(context: ctx)
        e.title = "BV Wegwerfen"
        for i in 1...3 {
            let a = Auftrag(context: ctx)
            a.processingDetails = "Paket \(i)"
            a.status = .pending; a.storageNote = ""; a.event = e
        }
        for i in 1...4 {
            let p = LVPosition(context: ctx)
            p.posNr = "31.00\(i)0"; p.bezeichnung = "Position \(i)"
            p.menge = 10; p.einheit = "m"; p.event = e
        }
        return e
    }

    /// 🔴 Der Kern: nach dem Löschen ist KEIN Auftrag mehr übrig.
    @Test func nachDemLoeschenBleibtNichtsLiegen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelleMitAllem(ctx)
        try ctx.save()

        #expect(BaustelleLoeschen.waisen(in: ctx).isEmpty, "vorher hängt alles an der Baustelle")

        BaustelleLoeschen.loesche(e, in: ctx)
        try ctx.save()

        #expect(BaustelleLoeschen.waisen(in: ctx).isEmpty, "und nachher liegt nichts herum")
        let alle = try ctx.fetch(Auftrag.fetchRequest()) as [Auftrag]
        #expect(alle.isEmpty)
    }

    /// Das alte Verhalten zum Vergleich — so entstanden die 965.
    @Test func dasAlteLoeschenLiessAllesLiegen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelleMitAllem(ctx)
        try ctx.save()

        ctx.delete(e)          // genau das, was vorher im Code stand
        try ctx.save()

        #expect(BaustelleLoeschen.waisen(in: ctx).count == 3,
                "Nullify kappt nur die Verbindung — die Aufträge bleiben")
    }

    /// Die Folgen stehen VOR der Tat da, mit Zahlen.
    @Test func dieFolgenWerdenVorherGenannt() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = baustelleMitAllem(ctx)
        try ctx.save()

        let f = BaustelleLoeschen.folgen(e)
        #expect(f.auftraege == 3)
        #expect(f.positionen == 4)
        #expect(f.satz.contains("3 Arbeitspakete"))
        #expect(f.satz.contains("4 LV-Positionen"))
    }

    @Test func eineLeereBaustelleSagtDas() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Leer"
        try ctx.save()
        #expect(BaustelleLoeschen.folgen(e).satz == "Die Baustelle ist leer.")
    }

    /// Aufräumen räumt auf — und lässt alles in Ruhe, was noch eine Baustelle hat.
    @Test func aufraeumenTrifftNurDieWaisen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext

        let bleibt = baustelleMitAllem(ctx)          // 3 Aufträge mit Baustelle
        let wird = baustelleMitAllem(ctx)
        try ctx.save()
        ctx.delete(wird)                             // altes Verhalten: 3 Waisen
        try ctx.save()

        #expect(BaustelleLoeschen.waisen(in: ctx).count == 3)
        let weg = BaustelleLoeschen.raeumeWaisenAuf(in: ctx)
        try ctx.save()

        #expect(weg == 3)
        #expect(BaustelleLoeschen.waisen(in: ctx).isEmpty)
        #expect(((bleibt.jobs?.allObjects as? [Auftrag]) ?? []).count == 3,
                "die andere Baustelle behält ihre Aufträge")
    }
}

// MARK: - 🔴 Was an Arbeitsschritten verloren geht
//
// "die arbeitsschritte bleiben ja erhalten oder, die liegen doch unter den
//  vorlagen oder?" (Andreas, 22.09.2026)
//
// Nur die ABGENOMMENEN. `AnweisungsKatalog.merken` nimmt bewusst nur Geprüftes,
// damit sich ungeprüfte Schritte nicht über alle Baustellen vermehren — die
// Kehrseite ist, dass ungeprüfte Arbeit beim Löschen verschwindet. Das muss vorher
// dastehen.

@MainActor
struct VerloreneSchritteTests {

    private func auftragMitSchritten(_ ctx: NSManagedObjectContext, _ e: Event,
                                     _ name: String, _ anzahl: Int) {
        let a = Auftrag(context: ctx)
        a.processingDetails = name
        a.status = .pending; a.storageNote = ""; a.event = e
        var p = AuftragExtrasPayload()
        p.checklist = (1...anzahl).map { AuftragChecklistItem(title: "Schritt \($0)") }
        if let d = try? JSONEncoder().encode(p) { a.extras = String(data: d, encoding: .utf8) }
    }

    @Test func ungepruefteSchritteWerdenGezaehlt() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Arbeit drin"
        auftragMitSchritten(ctx, e, "Ein ganz eigenartiger Auftragsname xyz", 8)
        auftragMitSchritten(ctx, e, "Noch ein eigenartiger Name abc", 5)
        try ctx.save()

        let f = BaustelleLoeschen.folgen(e)
        #expect(f.auftraegeMitSchritten == 2)
        #expect(f.schritteNurHier == 13)
        let satz = try #require(f.schritteSatz)
        #expect(satz.contains("13 Arbeitsschritte"))
        #expect(satz.contains("nicht abgenommen"))
    }

    /// Ohne Schritte kein Satz — es wird nur genannt, was es gibt.
    @Test func ohneSchritteKeinSatz() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Leer"
        let a = Auftrag(context: ctx)
        a.processingDetails = "Paket ohne Schritte"
        a.status = .pending; a.storageNote = ""; a.event = e
        try ctx.save()

        #expect(BaustelleLoeschen.folgen(e).schritteSatz == nil)
    }
}
