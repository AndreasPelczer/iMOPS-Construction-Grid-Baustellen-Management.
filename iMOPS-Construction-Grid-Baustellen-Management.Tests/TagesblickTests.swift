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

    /// 🔴 EINE KETTE IST KEIN ALARM. Ein Auftrag, der nur auf seinen Vorgänger wartet
    /// und selbst noch gar nicht läuft, gehört NICHT in die Blockaden — sonst meldet
    /// ein normaler Bauablauf mit 34 Paketen 33 rote Alarme (21.09. genau so passiert).
    @Test func diePlanketteIstKeineBlockade() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Kette")
        let erst = Auftrag(context: ctx)
        erst.processingDetails = "Aushub"; erst.status = .pending; erst.storageNote = ""; erst.event = e
        let dann = Auftrag(context: ctx)
        dann.processingDetails = "Bodenplatte"; dann.status = .pending; dann.storageNote = ""; dann.event = e
        let k = Voraussetzung(context: ctx)
        k.id = UUID(); k.typ = VoraussetzungsTyp.automatisch.rawValue
        k.quelle = erst; k.auftrag = dann
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.blockaden.isEmpty, "niemand steht — es hat noch keiner angefangen")
        #expect(t.startklar.count == 1, "nur der Aushub kann anfangen")
        #expect(t.startklar.first?.auftrag == "Aushub")

        // Sobald der zweite LÄUFT und der erste nicht fertig ist, steht wirklich jemand.
        dann.status = .inProgress
        try ctx.save()
        let t2 = Tagesblick.fuerHeute(in: ctx)
        #expect(t2.blockaden.count == 1)
        #expect(t2.blockaden.first?.auftrag == "Bodenplatte")
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

        // Gegenprobe: Vorgänger läuft noch UND der Nachfolger ist bereits angefangen
        // — erst dann steht wirklich jemand. (Wäre der Nachfolger nur „pending", wäre
        // das bloß Plan; siehe `diePlanketteIstKeineBlockade`.)
        vorher.status = .inProgress
        danach.status = .inProgress
        try ctx.save()
        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.blockaden.count == 1)
        #expect(t.blockaden.first?.fehlt == "Schalung stellen",
                "eine namenlose Kante wird nach ihrem Vorgänger benannt")
    }

    /// 🔴 Eine Baustelle in PLANUNG kann gar nicht blockiert sein. Andreas, 21.09.:
    /// „Erst wenn wirklich Alarm ist, auch Alarm rufen — bis jetzt haben wir doch nur
    /// eine Baustelle, die noch geplant werden muss."
    @Test func einePlanungsbaustelleSchlaegtKeinenAlarm() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Planung")
        e.eventStartTime = nil
        for name in ["Aushub", "Bodenplatte", "Mauerwerk"] {
            let a = Auftrag(context: ctx)
            a.processingDetails = name; a.status = .pending
            a.storageNote = ""; a.dauerTage = 0; a.event = e
        }
        position(ctx, e, "01.0010", preis: nil)
        try ctx.save()

        let t = Tagesblick.fuerHeute(in: ctx)
        #expect(t.blockaden.isEmpty, "in der Planung steht niemand")

        let l = try #require(t.lagen.first)
        #expect(l.phase == .planung)
        #expect(l.pakete == 3)
        // Was anstünde, freundlich statt rot:
        let texte = l.anstehend.map(\.text).joined(separator: " | ")
        #expect(texte.contains("Baubeginn"), "kein Starttermin gesetzt")
        #expect(texte.contains("keine Dauer"))
        #expect(texte.contains("Niemand ist zugeteilt"))
        #expect(texte.contains("keinen Preis"))
    }

    /// Sobald jemand arbeitet, heißt die Baustelle „läuft" — und erst dort sind
    /// Blockaden überhaupt möglich.
    @Test func sobaldJemandArbeitetLaeuftDieBaustelle() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { aufraeumen() }

        let e = baustelle(ctx, "BV Läuft")
        let a = Auftrag(context: ctx)
        a.processingDetails = "Aushub"; a.status = .inProgress
        a.storageNote = ""; a.dauerTage = 2; a.employeeName = "Paolo"; a.event = e
        e.eventStartTime = Date()
        try ctx.save()

        let l = try #require(Tagesblick.fuerHeute(in: ctx).lagen.first)
        #expect(l.phase == .laeuft)
        #expect(l.anstehend.isEmpty, "alles gesetzt — nichts steht an")
    }
}

// MARK: - Die Phase: EINE Wahrheit für Liste und Tagesblick
//
// Bis 21.09.2026 rechneten die Reiter der Baustellenliste mit dem KALENDER:
// Endtermin vorbei = "Abgeschlossen", auch wenn kein Handschlag getan war.
// Der Tagesblick rechnete daneben die echte Phase aus den Aufträgen.
// Diese Tests halten die beiden zusammen.

@MainActor
struct PhaseDerBaustelleTests {

    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event,
                         _ was: String, _ status: JobStatus) {
        let a = Auftrag(context: ctx)
        a.processingDetails = was
        a.status = status
        a.storageNote = ""          // Pflichtfeld ohne Default
        a.event = e
    }

    @Test func ohneAuftraegeWirdGeplant() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Leer"
        #expect(Tagesblick.Phase.von(e) == .planung)
    }

    @Test func nurOffeneAuftraegeSindNochPlanung() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Geplant"
        auftrag(ctx, e, "Aushub", .pending)
        auftrag(ctx, e, "Bodenplatte", .pending)
        #expect(Tagesblick.Phase.von(e) == .planung)
    }

    @Test func einLaufenderAuftragMachtDieBaustelleLaufend() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Angefangen"
        auftrag(ctx, e, "Aushub", .inProgress)
        auftrag(ctx, e, "Bodenplatte", .pending)
        #expect(Tagesblick.Phase.von(e) == .laeuft)
    }

    /// Auch wenn gerade niemand arbeitet: was fertig ist, ist angefangen.
    @Test func einFertigerAuftragZaehltAlsAngefangen() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Pause"
        auftrag(ctx, e, "Aushub", .completed)
        auftrag(ctx, e, "Bodenplatte", .pending)
        #expect(Tagesblick.Phase.von(e) == .laeuft)
    }

    @Test func erstWennAllesErledigtIstIstDieBaustelleFertig() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Fertig"
        auftrag(ctx, e, "Aushub", .completed)
        auftrag(ctx, e, "Bodenplatte", .completed)
        #expect(Tagesblick.Phase.von(e) == .fertig)
    }

    /// 🔴 Der eigentliche Befund: ein verstrichener Endtermin macht keine Baustelle fertig.
    /// Die alte Liste hätte diese hier unter "Abgeschlossen" einsortiert.
    @Test func verstrichenerEndterminMachtNichtFertig() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Überfällig"
        e.eventEndTime = Date().addingTimeInterval(-60 * 60 * 24 * 30)   // vor einem Monat
        auftrag(ctx, e, "Aushub", .pending)
        #expect(Tagesblick.Phase.von(e) == .planung)
    }

    /// Umgekehrt: fertig ist fertig, auch wenn der Termin noch läuft.
    @Test func fertigVorDemEndterminIstTrotzdemFertig() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Früh dran"
        e.eventEndTime = Date().addingTimeInterval(60 * 60 * 24 * 30)    // in einem Monat
        auftrag(ctx, e, "Aushub", .completed)
        #expect(Tagesblick.Phase.von(e) == .fertig)
    }

    /// Jeder Reiter zeigt genau eine Phase — und "Alle" lässt alles durch.
    @Test func jederReiterZeigtSeinePhase() {
        #expect(EventFilter.planung.phase == .planung)
        #expect(EventFilter.laeuft.phase  == .laeuft)
        #expect(EventFilter.fertig.phase  == .fertig)
        #expect(EventFilter.alle.phase    == nil)
    }

    /// Die Reiter heissen wie die Phasen im Tagesblick — sonst reden zwei Ansichten
    /// über dasselbe in verschiedenen Wörtern.
    @Test func reiterUndTagesblickBenutzenDieselbenWoerter() {
        #expect(Tagesblick.Phase.planung.text == "wird geplant")
        #expect(Tagesblick.Phase.laeuft.text  == "läuft")
        #expect(Tagesblick.Phase.fertig.text  == "fertig")
        #expect(EventFilter.laeuft.rawValue.lowercased() == Tagesblick.Phase.laeuft.text)
        #expect(EventFilter.fertig.rawValue.lowercased() == Tagesblick.Phase.fertig.text)
    }
}
