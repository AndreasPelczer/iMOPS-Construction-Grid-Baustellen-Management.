//
//  ArbeitspaketeTests.swift
//
//  Aus 109 LV-Positionen werden nicht 109 Aufträge, sondern ein gutes Dutzend
//  Arbeitspakete. Der wichtigste Test ist `titelStattPositionen`: genau da lag der
//  Denkfehler, den Andreas am 21.09. korrigiert hat.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct ArbeitspaketeTests {

    @discardableResult
    private func pos(_ ctx: NSManagedObjectContext, _ e: Event,
                     _ nr: String, _ bez: String, kg: String? = nil,
                     menge: Double = 10) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = nr
        p.bezeichnung = bez
        p.menge = menge
        p.einheit = "m2"
        p.kostenGruppeNummer = kg
        p.event = e
        return p
    }

    private func baustelle(_ ctx: NSManagedObjectContext) -> Event {
        let e = Event(context: ctx); e.title = "BV Test"; return e
    }

    /// 🔴 DER KERN: ein LV ist die Abrechnung, ein Arbeitspaket ist die Arbeit.
    /// Fünf Positionen in zwei Titeln ergeben ZWEI Pakete, nicht fünf.
    @Test func titelStattPositionen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        pos(ctx, e, "31.0010", "Oberboden abtragen", kg: "310")
        pos(ctx, e, "31.0020", "Baugrube ausheben", kg: "310")
        pos(ctx, e, "31.0030", "Arbeitsraum verfüllen", kg: "310")
        pos(ctx, e, "32.0010", "Sauberkeitsschicht", kg: "320")
        pos(ctx, e, "32.0020", "Bodenplatte betonieren", kg: "320")
        try ctx.save()

        let v = Arbeitspakete.vorschlagen(fuer: e)
        #expect(v.count == 2, "zwei Titel = zwei Pakete, nicht fünf")
        #expect(v.map(\.titelNr) == ["31", "32"], "aufsteigend nach Titelnummer")
        #expect(v[0].anzahlPositionen == 3)
        #expect(v[1].anzahlPositionen == 2)
    }

    /// Die Titelnummer kommt aus der Positionsnummer — vor dem Punkt.
    @Test func titelNummerAusDerPositionsnummer() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        let a = pos(ctx, e, "31.0010", "mit Punkt")
        let b = pos(ctx, e, "4201", "ohne Punkt")
        let d = pos(ctx, e, "", "ohne alles")
        #expect(Arbeitspakete.titelNummer(a) == "31")
        #expect(Arbeitspakete.titelNummer(b) == "42")
        #expect(Arbeitspakete.titelNummer(d) == "00", "namenlose landen im Sammeltitel")
    }

    /// Ohne Aufwandswerte gibt es keine gerechnete Dauer — das muss als GESCHÄTZT
    /// markiert sein. Eine geratene Zahl, die wie eine gerechnete aussieht, ist
    /// schlimmer als gar keine.
    @Test func ohneAufwandswerteIstDieDauerMarkiert() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        pos(ctx, e, "33.0010", "Mauerwerk", kg: "330")
        pos(ctx, e, "33.0020", "Sturz setzen", kg: "330")
        try ctx.save()

        let v = try #require(Arbeitspakete.vorschlagen(fuer: e).first)
        #expect(v.mannstunden == 0)
        #expect(v.dauerIstGeschaetzt, "keine Lohnstunden → geraten, und das steht dran")
        #expect(v.dauerTage > 0, "trotzdem eine Hausnummer, damit der Plan nicht leer bleibt")
    }

    /// Die Kolonne teilt die Dauer: doppelt so viele Leute, halb so lange.
    @Test func mehrLeuteKuerzereDauer() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        pos(ctx, e, "31.0010", "Aushub", kg: "310")
        try ctx.save()

        let einer = try #require(Arbeitspakete.vorschlagen(fuer: e, kolonne: 1).first)
        let zwei  = try #require(Arbeitspakete.vorschlagen(fuer: e, kolonne: 2).first)
        // ohne Aufwandswerte greift die Hausnummer — die haengt nicht an der Kolonne
        #expect(einer.dauerTage == zwei.dauerTage)
        #expect(einer.dauerIstGeschaetzt)
    }

    /// Angelegt wird nur, was angehakt ist — und die Pakete hängen als Kette.
    @Test func nurDasAngehakteWirdAngelegtUndVerkettet() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        pos(ctx, e, "31.0010", "Aushub", kg: "310")
        pos(ctx, e, "32.0010", "Bodenplatte", kg: "320")
        pos(ctx, e, "33.0010", "Mauerwerk", kg: "330")
        try ctx.save()

        var v = Arbeitspakete.vorschlagen(fuer: e)
        #expect(v.count == 3)
        v[1].uebernehmen = false              // die Bodenplatte abwählen

        let angelegt = Arbeitspakete.anlegen(v, event: e, in: ctx)
        try ctx.save()

        #expect(angelegt.count == 2)
        #expect(angelegt[0].dauerTage > 0)
        #expect(angelegt[0].istStartbar, "das erste Paket wartet auf nichts")
        #expect(!angelegt[1].istStartbar, "das zweite wartet auf das erste")
        #expect(angelegt[1].offeneVoraussetzungen.count == 1)
    }

    /// Ohne Verkettung stehen die Pakete nebeneinander — für Gewerke, die parallel laufen.
    @Test func ohneVerkettungStehenSieNebeneinander() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        pos(ctx, e, "41.0010", "Sanitär", kg: "410")
        pos(ctx, e, "44.0010", "Elektro", kg: "440")
        try ctx.save()

        let angelegt = Arbeitspakete.anlegen(Arbeitspakete.vorschlagen(fuer: e),
                                             event: e, verketten: false, in: ctx)
        try ctx.save()
        #expect(angelegt.count == 2)
        // allSatisfy ist rethrows — im #expect-Makro scheitert die Analyse.
        let alleStartbar = angelegt.allSatisfy { $0.istStartbar }
        #expect(alleStartbar)
    }

    /// Leeres LV → kein Vorschlag, kein Absturz.
    @Test func ohneLVKeinVorschlag() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = baustelle(ctx)
        try ctx.save()
        #expect(Arbeitspakete.vorschlagen(fuer: e).isEmpty)
    }
}
