//
//  WochenstrahlTests.swift
//
//  Der Wochenstrahl rechnet Tage in Kalendertage um — und genau da passieren
//  Fehler, die auf dem Bildschirm plausibel aussehen: ein Auftrag, der über das
//  Wochenende einfach durchläuft, oder einer, der einen Tag zu lang steht.
//
//  Der wichtigste Test ist `wochenendeWirdUebersprungen`: Samstag und Sonntag sind
//  keine Arbeitstage, und wer das nicht zählt, verspricht dem Bauherrn zwei Tage,
//  die es nicht gibt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct WochenstrahlTests {

    /// Montag, 21.09.2026 — der Anker aller Tests hier.
    private func tag(_ j: Int, _ m: Int, _ t: Int) -> Date {
        var c = DateComponents(); c.year = j; c.month = m; c.day = t; c.hour = 8
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        cal.firstWeekday = 2
        return cal.date(from: c)!
    }

    @discardableResult
    private func baustelle(_ ctx: NSManagedObjectContext, _ name: String, start: Date?) -> Event {
        let e = Event(context: ctx)
        e.title = name
        e.eventStartTime = start
        return e
    }

    @discardableResult
    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event,
                         _ name: String, dauer: Double) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = name
        a.dauerTage = dauer
        a.status = .pending
        a.storageNote = ""          // Pflichtfeld ohne Default
        a.event = e
        return a
    }

    /// Drei Tage ab Montag heißt Mo, Di, Mi — nicht Do.
    @Test func dreiTageAbMontagBelegenDreiTage() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let montag = tag(2026, 9, 21)
        let e = baustelle(ctx, "BV Montag", start: montag)
        auftrag(ctx, e, "Schalung stellen", dauer: 3)
        try ctx.save()

        let w = Wochenstrahl.woche(um: montag, in: ctx)
        let belegt = w.tage.filter { !$0.eintraege.isEmpty }.map(\.kuerzel)
        #expect(belegt == ["Mo", "Di", "Mi"])
        #expect(w.tage[0].eintraege.first?.beginntHeute == true)
        #expect(w.tage[2].eintraege.first?.endetHeute == true)
    }

    /// 🔴 Samstag und Sonntag sind keine Arbeitstage. Drei Tage ab Donnerstag
    /// belegen Do und Fr — der dritte fällt auf den Montag danach, nicht auf Samstag.
    @Test func wochenendeWirdUebersprungen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let donnerstag = tag(2026, 9, 24)
        let e = baustelle(ctx, "BV Wochenende", start: donnerstag)
        auftrag(ctx, e, "Beton einbringen", dauer: 3)
        try ctx.save()

        let diese = Wochenstrahl.woche(um: donnerstag, in: ctx)
        #expect(diese.tage.filter { !$0.eintraege.isEmpty }.map(\.kuerzel) == ["Do", "Fr"])

        let naechste = Wochenstrahl.woche(um: donnerstag, versatz: 1, in: ctx)
        #expect(naechste.tage.filter { !$0.eintraege.isEmpty }.map(\.kuerzel) == ["Mo"],
                "der dritte Arbeitstag ist der Montag, nicht der Samstag")
    }

    /// Die Kette aus `Bauablauf` trägt: der Nachfolger fängt an, wenn der
    /// Vorgänger fertig ist — hier also am Mittwoch.
    @Test func derNachfolgerRutschtHinterDenVorgaenger() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let montag = tag(2026, 9, 21)
        let e = baustelle(ctx, "BV Kette", start: montag)
        let erst = auftrag(ctx, e, "Schalung", dauer: 2)
        let dann = auftrag(ctx, e, "Beton", dauer: 1)
        let kante = Voraussetzung(context: ctx)
        kante.id = UUID()
        kante.name = "Schalung"
        kante.typ = VoraussetzungsTyp.automatisch.rawValue
        kante.quelle = erst
        kante.auftrag = dann
        try ctx.save()

        let w = Wochenstrahl.woche(um: montag, in: ctx)
        let mittwoch = try #require(w.tage.first { $0.kuerzel == "Mi" })
        #expect(mittwoch.eintraege.map(\.auftrag) == ["Beton"])
        let montagTag = try #require(w.tage.first { $0.kuerzel == "Mo" })
        #expect(montagTag.eintraege.map(\.auftrag) == ["Schalung"])
    }

    /// 🔴 Ohne Dauer wird NICHTS gemalt — aber die Lücke wird benannt.
    /// Ein leerer Kalender, der nicht sagt warum, ist schlimmer als keiner.
    @Test func ohneDauerWirdNichtsErfunden() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let montag = tag(2026, 9, 21)
        let e = baustelle(ctx, "BV Ohne Dauer", start: montag)
        auftrag(ctx, e, "Irgendwas", dauer: 0)
        auftrag(ctx, e, "Noch was", dauer: 0)
        try ctx.save()

        let w = Wochenstrahl.woche(um: montag, in: ctx)
        #expect(!w.hatInhalt)
        #expect(w.luecken.auftraegeOhneDauer == 2)
        #expect(w.luecken.baustellenOhneDauer == ["BV Ohne Dauer"])
        #expect(!w.luecken.istVollstaendig)
    }

    /// Ohne Baubeginn gibt es keinen Tag 1 — auch das wird gesagt, nicht geraten.
    @Test func ohneStartterminWirdGemeldet() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx, "BV Ohne Start", start: nil)
        auftrag(ctx, e, "Aushub", dauer: 2)
        try ctx.save()

        let w = Wochenstrahl.woche(um: tag(2026, 9, 21), in: ctx)
        #expect(w.luecken.baustellenOhneStart == ["BV Ohne Start"])
        #expect(!w.hatInhalt)
    }

    /// Mehrere Baustellen stehen am selben Tag nebeneinander — der ganze Zweck.
    @Test func zweiBaustellenAmSelbenTag() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let montag = tag(2026, 9, 21)
        let a = baustelle(ctx, "BV Alpha", start: montag)
        auftrag(ctx, a, "Kimmschicht", dauer: 2)
        let b = baustelle(ctx, "BV Beta", start: montag)
        auftrag(ctx, b, "Aushub", dauer: 5)
        try ctx.save()

        let w = Wochenstrahl.woche(um: montag, in: ctx)
        let mo = try #require(w.tage.first)
        #expect(mo.eintraege.count == 2)
        #expect(mo.eintraege.map(\.baustelle) == ["BV Alpha", "BV Beta"])
        #expect(w.luecken.istVollstaendig)
    }

    /// Eine Mängelfrist braucht keinen Baustellenstart — sie trägt ihr Datum selbst.
    @Test func fristErscheintAmIhremTag() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let montag = tag(2026, 9, 21)
        let e = baustelle(ctx, "BV Frist", start: nil)
        let m = Mangel(context: ctx)
        m.id = UUID()
        m.titel = "Estrich nacharbeiten"
        m.frist = tag(2026, 9, 23)
        m.status = .offen
        m.event = e
        try ctx.save()

        let w = Wochenstrahl.woche(um: montag, in: ctx)
        let mi = try #require(w.tage.first { $0.kuerzel == "Mi" })
        #expect(mi.termine.map(\.was) == ["Estrich nacharbeiten"])
    }
}
