//
//  KennwertAusProjektenTests.swift
//
//  Der Hausplaner rechnet alles aus EINER Zahl hoch (2.000/2.500/3.200 €/m²) und
//  verteilt sie nach festen Prozenten. Diese Zahlen sind Vorgaben — geraten. Das ist
//  in Ordnung, solange man es sieht. Schlecht wird es, wenn eine geratene Zahl genauso
//  aussieht wie eine gerechnete.
//
//  Diese Tests halten fest, dass der Rückweg funktioniert: aus echten LVs die eigenen
//  €/m² lernen. Und vor allem, dass eine einzelne Baustelle NICHT als belastbar gilt —
//  ein Projekt ist ein Anhaltspunkt, kein Erfahrungswert.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct KennwertAusProjektenTests {

    /// Eine Baustelle mit Wohnfläche (aus dem Planer) und bepreisten LV-Positionen.
    ///
    /// Der Preis kommt als ANGEBOT — `LVKalkulator.effektiverEP` liest den Einkaufspreis
    /// nicht, sondern nur Angebot, Element oder Tiefenkalkulation. Wer hier `einkaufspreis`
    /// setzt, testet an der Rechnung vorbei.
    @discardableResult
    private func baustelle(_ ctx: NSManagedObjectContext, wohnflaeche: Double,
                           positionen: [(kg: String, menge: Double, ep: Double)]) -> Event {
        let e = Event(context: ctx)
        e.title = "Test \(wohnflaeche) m²"
        var projekt = HouseProject()
        projekt.wohnflaeche = wohnflaeche
        var extras = EventExtrasPayload()
        extras.houseProject = projekt
        extras.speichern(in: e)

        for (kg, menge, ep) in positionen {
            let p = LVPosition(context: ctx)
            p.posNr = kg + ".0010"
            p.bezeichnung = "Position \(kg)"
            p.kostenGruppeNummer = kg
            p.menge = menge
            p.einheit = "m2"
            p.event = e
            try? ctx.obtainPermanentIDs(for: [p])
            let id = p.objectID.uriRepresentation().absoluteString
            AngebotsStore.shared.upsert(Angebot(lieferant: TESTLIEFERANT, einzelpreis: ep), for: id)
            angelegteIDs.append(id)
        }
        try? ctx.save()
        return e
    }

    /// Der AngebotsStore ist ein Singleton auf Platte — was ein Test dort ablegt, sieht
    /// jeder andere. Also hinterher wegräumen.
    private let TESTLIEFERANT = "Test-Kennwert"
    private final class IDSpeicher { var werte: [String] = [] }
    private let speicher = IDSpeicher()
    private var angelegteIDs: [String] {
        get { speicher.werte }
        nonmutating set { speicher.werte = newValue }
    }
    private func aufraeumen() {
        for id in angelegteIDs { AngebotsStore.shared.remove(lieferant: TESTLIEFERANT, for: id) }
        angelegteIDs = []
    }

    /// Der Fall von heute: eine echte Baustelle, echte Zahl je m².
    @Test func eineBaustelleLiefertIhrenEigenenKennwert() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        // 100 m² Wohnfläche, Rohbau (KG 330) 90.000 € -> 900 €/m²
        baustelle(ctx, wohnflaeche: 100, positionen: [("330", 900, 100)])

        let e = KennwertAusProjekten.lerne(in: ctx)
        #expect(e.projekte == 1)
        let rohbau = try #require(e.jeTopf["Rohbau"])
        #expect(abs(rohbau.euroProQm - 900) < 0.01)
        #expect(rohbau.projekte == 1)
    }

    /// Ein einziges Projekt ist KEIN Erfahrungswert. Das muss die Oberfläche sagen
    /// können, sonst verkauft sie einen Zufall als Wissen.
    @Test func eineinzelnesProjektGiltNichtAlsBelastbar() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }
        baustelle(ctx, wohnflaeche: 100, positionen: [("330", 900, 100)])

        let rohbau = try #require(KennwertAusProjekten.lerne(in: ctx).jeTopf["Rohbau"])
        #expect(!rohbau.belastbar)
        #expect(rohbau.herkunft == "aus 1 eigenen Projekt")
    }

    /// Mehrere Projekte werden über die Fläche gewichtet, nicht gemittelt: ein großes
    /// Haus zählt mehr als ein kleines. Sonst verzerrt ein Bungalow die Reihe.
    @Test func mehrereProjekteWerdenUeberDieFlaecheGewichtet() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }
        baustelle(ctx, wohnflaeche: 100, positionen: [("330", 1000, 100)])   // 1000 €/m²
        baustelle(ctx, wohnflaeche: 300, positionen: [("330", 1500, 100)])   //  500 €/m²

        let rohbau = try #require(KennwertAusProjekten.lerne(in: ctx).jeTopf["Rohbau"])
        // (100.000 + 150.000) / (100 + 300) = 625 — nicht (1000+500)/2 = 750
        #expect(abs(rohbau.euroProQm - 625) < 0.01)
        #expect(rohbau.projekte == 2)
    }

    /// Baustellen ohne Planer-Daten oder ohne LV dürfen die Zahlen nicht verwässern.
    @Test func baustellenOhneFlaecheOderOhneLVZaehlenNicht() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }
        let ohneLV = Event(context: ctx)
        ohneLV.title = "nur Planer"
        var pr = HouseProject(); pr.wohnflaeche = 150
        var ex = EventExtrasPayload(); ex.houseProject = pr; ex.speichern(in: ohneLV)

        let ohnePlaner = Event(context: ctx)
        ohnePlaner.title = "nur LV"
        let p = LVPosition(context: ctx)
        p.kostenGruppeNummer = "330"; p.menge = 10; p.event = ohnePlaner
        try ctx.save()

        #expect(KennwertAusProjekten.lerne(in: ctx).projekte == 0)
    }

    /// Wo es keine eigenen Zahlen gibt, muss die Zeile als geschätzt erkennbar sein.
    @Test func ohneEigeneZahlenBleibtEsSichtbarGeschaetzt() {
        let leer = KennwertAusProjekten.Ergebnis(jeTopf: [:], projekte: 0,
                                                 gesamtProQm: 0, flaeche: 0)
        let h = KennwertAusProjekten.herkunft(fuer: "Dach", erfahrung: leer)
        #expect(!h.istEcht)
        #expect(h.kurz.contains("geschätzt"))
        #expect(h.kurz.contains("8 %"))     // Dach = 8 % vom Kennwert
    }
}
