//
//  TagesblickTests.swift
//
//  Die Klammer über alle Baustellen. Der Mops konnte diese Fragen immer beantworten —
//  aber nur je Baustelle, nie quer. Genau das war der Befund vom 21.09.: von zehn
//  Büro-Bausteinen fünf fertig, fünf halb, und bei dreien stand wörtlich „je Baustelle".
//
//  Der wichtigste Test ist `rechnetWieDasLV`: sagt der Tagesblick etwas anderes als die
//  LV-Ansicht, ist er schlimmer als nichts — dann stehen zwei Wahrheiten nebeneinander,
//  und genau daran ist am 20.09. eine ganze Kalkulation gescheitert.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct TagesblickTests {

    private let LIEFERANT = "Test-Tagesblick"
    private final class Merker { var ids: [String] = [] }
    private let merker = Merker()
    private func aufraeumen() {
        for id in merker.ids { AngebotsStore.shared.remove(lieferant: LIEFERANT, for: id) }
        merker.ids = []
    }

    @discardableResult
    private func baustelle(_ ctx: NSManagedObjectContext, _ name: String) -> Event {
        let e = Event(context: ctx); e.title = name; return e
    }

    private func position(_ ctx: NSManagedObjectContext, _ e: Event,
                          _ posNr: String, preis: Double?) {
        let p = LVPosition(context: ctx)
        p.posNr = posNr; p.bezeichnung = "Position \(posNr)"
        p.menge = 10; p.einheit = "m2"; p.event = e
        if let preis {
            try? ctx.obtainPermanentIDs(for: [p])
            let id = p.objectID.uriRepresentation().absoluteString
            AngebotsStore.shared.upsert(Angebot(lieferant: LIEFERANT, einzelpreis: preis), for: id)
            merker.ids.append(id)
        }
    }

    /// Eine unerfüllte Voraussetzung an einem laufenden Auftrag = jemand steht.
    @Test func einUnerfuelltesHindernisWirdGemeldet() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Nord")
        let a = Auftrag(context: ctx)
        a.processingDetails = "Bewehrung OG einlegen"
        a.status = .inProgress
        a.storageNote = ""           // Pflichtfeld ohne Default — sonst wirft save()
        a.event = e
        let v = Voraussetzung(context: ctx)
        v.id = UUID()
        v.name = "Abstandhalter geliefert"
        v.typ = VoraussetzungsTyp.manuell.rawValue
        v.erfuellt = false
        v.auftrag = a
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.blockaden.count == 1)
        #expect(t.blockaden.first?.fehlt == "Abstandhalter geliefert")
        #expect(t.blockaden.first?.baustelle == "BV Nord")
        // 🔴 Die Blockade muss den AUFTRAG tragen, nicht nur seinen Namen — sonst
        // landet man beim Antippen auf der Baustellenseite und darf suchen.
        #expect(t.blockaden.first?.job === a)
        #expect(!t.istRuhig)
    }

    /// Ein erledigter Auftrag blockiert niemanden mehr — auch wenn die Voraussetzung
    /// nie abgehakt wurde. Sonst steht die Liste voll mit alten Karteileichen.
    @Test func erledigteAuftraegeBlockierenNicht() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Süd")
        let a = Auftrag(context: ctx)
        a.processingDetails = "längst fertig"
        a.status = .completed
        a.storageNote = ""
        a.event = e
        let v = Voraussetzung(context: ctx)
        v.id = UUID(); v.name = "irgendwas"; v.erfuellt = false; v.auftrag = a
        position(ctx, e, "01.0010", preis: 50)   // damit die Baustelle als aktiv zählt
        try ctx.save()

        #expect(Tagesblick.fuerHeute(in: ctx).blockaden.isEmpty)
    }

    /// DER WICHTIGSTE TEST: dieselbe Preisrechnung wie im LV. Weicht der Tagesblick ab,
    /// stehen zwei Wahrheiten nebeneinander — der Fehler vom 20.09. (15.255 gegen
    /// 256.742 EUR) entstand genau so.
    @Test func rechnetWieDasLV() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Preise")
        position(ctx, e, "01.0010", preis: 100)   // hat einen Preis
        position(ctx, e, "01.0020", preis: nil)   // hat keinen
        position(ctx, e, "01.0030", preis: nil)   // hat keinen
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        let l = try #require(t.preisluecken.first)
        #expect(l.anzahl == 3)
        #expect(l.betroffeneMenge == 2)

        // Gegenprobe direkt über LVKalkulator — muss dieselbe Zahl sein.
        let alle = ((e.lvPositionen as? Set<LVPosition>) ?? [])
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }.zaehlbarePositionen()
        let ohne = alle.filter { LVKalkulator.effektiverEP(for: $0) <= 0 }.count
        #expect(l.betroffeneMenge == ohne, "Tagesblick und LV rechnen verschieden")
    }

    /// Über mehrere Baustellen hinweg — das ist der ganze Punkt dieser Sicht.
    @Test func sammeltUeberAlleBaustellen() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        for name in ["BV Eins", "BV Zwei", "BV Drei"] {
            let e = baustelle(ctx, name)
            position(ctx, e, "01.0010", preis: nil)
        }
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.baustellenAktiv == 3)
        #expect(t.preisluecken.count == 3)
    }

    /// Leere Baustellen (angelegt, nichts drin) dürfen die Liste nicht zumüllen.
    @Test func leereBaustellenZaehlenNicht() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        baustelle(ctx, "nur angelegt")
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.baustellenAktiv == 0)
        #expect(t.istRuhig)
    }

    /// Eine KANTE (Auftrag wartet auf Auftrag) ist erfüllt, sobald der Vorgänger fertig
    /// ist — das Häkchen `erfuellt` bleibt dabei auf „nein". Wer roh danach filtert,
    /// meldet Blockaden, die längst keine mehr sind. Genau das war mein erster Entwurf.
    @Test func fertigerVorgaengerBlockiertNicht() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Kette")
        let vorher = Auftrag(context: ctx)
        vorher.processingDetails = "Schalung stellen"
        vorher.status = .completed
        vorher.storageNote = ""
        vorher.event = e

        let danach = Auftrag(context: ctx)
        danach.processingDetails = "Beton einbringen"
        danach.status = .pending
        danach.storageNote = ""
        danach.event = e

        let kante = Voraussetzung(context: ctx)
        kante.id = UUID()
        kante.typ = VoraussetzungsTyp.automatisch.rawValue
        kante.erfuellt = false        // bleibt bewusst auf nein
        kante.quelle = vorher
        kante.auftrag = danach
        try ctx.save()

        #expect(Tagesblick.fuerHeute(in: ctx).blockaden.isEmpty,
                "erfüllte Kante darf nicht als Blockade erscheinen")

        // Gegenprobe: ist der Vorgänger NICHT fertig, muss sie erscheinen.
        vorher.status = .inProgress
        try ctx.save()
        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.blockaden.count == 1)
        #expect(t.blockaden.first?.fehlt == "Schalung stellen",
                "eine namenlose Kante wird nach ihrem Vorgänger benannt")
    }
}
