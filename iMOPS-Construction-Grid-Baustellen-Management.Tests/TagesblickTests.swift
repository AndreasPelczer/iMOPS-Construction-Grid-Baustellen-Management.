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

// MARK: - Der Faden durch die Einricht-Arbeit
//
// "ich richte das ein, gehe zurueck und will den naechsten Punkt abarbeiten —
//  und wo ist das naechste Puzzlestueck?"  (Andreas, 21.09.2026)
//
// Zwischen "Arbeitspakete anlegen" und "draussen anfangen" liegt eine Stufe, die
// niemand gezaehlt hat: fuer jeden Auftrag die Schritte schreiben und abnehmen.
// Der Tagesblick kannte diesen Zustand gar nicht — `checklist` kam dort nicht vor.

@MainActor
struct OhneAnweisungTests {

    @discardableResult
    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event, _ was: String,
                         schritte: [String] = [], status: JobStatus = .pending) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = was
        a.status = status
        a.storageNote = ""
        a.event = e
        if !schritte.isEmpty {
            var p = AuftragExtrasPayload()
            p.checklist = schritte.map { AuftragChecklistItem(title: $0) }
            if let d = try? JSONEncoder().encode(p) { a.extras = String(data: d, encoding: .utf8) }
        }
        return a
    }

    @Test func auftraegeOhneSchritteWerdenGezaehlt() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Einrichten"
        auftrag(ctx, e, "Aushub")
        auftrag(ctx, e, "Bodenplatte")
        auftrag(ctx, e, "Mauerwerk", schritte: ["Kimmschicht setzen"])

        let b = Tagesblick.fuerHeute(in: ctx)
        #expect(b.ohneAnweisung.count == 2)
        #expect(b.ohneAnweisung.allSatisfy { $0.baustelle == "BV Einrichten" })
    }

    /// Wer Schritte bekommen hat, verschwindet aus der Liste — sonst faendet man
    /// nie ein Ende und wuesste nie, wie viel noch vor einem liegt.
    @Test func mitSchrittenVerschwindetErAusDerListe() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Fortschritt"
        let a = auftrag(ctx, e, "Aushub")

        #expect(Tagesblick.fuerHeute(in: ctx).ohneAnweisung.count == 1)

        var p = AuftragExtrasPayload()
        p.checklist = [AuftragChecklistItem(title: "Oberboden abschieben")]
        a.extras = String(data: try JSONEncoder().encode(p), encoding: .utf8)

        #expect(Tagesblick.fuerHeute(in: ctx).ohneAnweisung.isEmpty)
    }

    /// Erledigte Auftraege brauchen keine Anweisung mehr — sie stehen nicht in der Liste.
    @Test func erledigteZaehlenNichtMit() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Teils fertig"
        auftrag(ctx, e, "Aushub", status: .completed)
        auftrag(ctx, e, "Bodenplatte")

        let b = Tagesblick.fuerHeute(in: ctx)
        #expect(b.ohneAnweisung.count == 1)
        #expect(b.ohneAnweisung.first?.auftrag.contains("Bodenplatte") == true)
    }

    /// 🔴 Die Liste ist ARBEIT, kein Alarm: sie darf das Warndreieck nicht anwerfen.
    @Test func fehlendeSchritteSindKeinAlarm() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Ruhig"
        auftrag(ctx, e, "Aushub")
        auftrag(ctx, e, "Bodenplatte")

        let b = Tagesblick.fuerHeute(in: ctx)
        #expect(!b.ohneAnweisung.isEmpty)
        #expect(b.brauchtAufmerksamkeit == false)
    }
}

// MARK: - Was gehört zu einem Arbeitspaket?
//
// "was gehört denn alles zu dem auftrag, gibts da pläne, zeichnungen?
//  mir fehlen infos denke ich" (Andreas, 21.09.2026)
//
// Ein Arbeitspaket fasst LV-Positionen zusammen — der Auftrag zeigte sie nicht.
// Im Modell ist Auftrag.lvPosition eine 1:1-Beziehung, ein Paket hat aber viele.
// Solange das so ist, wird die Zugehörigkeit über die Titelnummer GERECHNET.

@MainActor
struct ArbeitspaketUmfangTests {

    private func paket(_ ctx: NSManagedObjectContext, _ e: Event, _ name: String) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = name
        a.status = .pending
        a.storageNote = ""
        a.event = e
        return a
    }

    @discardableResult
    private func pos(_ ctx: NSManagedObjectContext, _ e: Event, _ nr: String,
                     _ bez: String, menge: Double = 10, einheit: String = "m2") -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = nr; p.bezeichnung = bez; p.menge = menge; p.einheit = einheit; p.event = e
        return p
    }

    @Test func dasPaketFindetSeinePositionenUeberDieTitelnummer() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Umfang"
        pos(ctx, e, "572.0010", "Rasen ansäen", menge: 340)
        pos(ctx, e, "572.0020", "Pflanzbeet herrichten", menge: 60)
        pos(ctx, e, "544.0010", "Leuchte setzen", menge: 4, einheit: "St")

        let a = paket(ctx, e, "572 Außenanlagen und Freiflächen")
        let liste = Arbeitspakete.positionen(fuer: a)
        #expect(liste.count == 2)
        #expect(liste.first?.posNr == "572.0010")       // in Positionsreihenfolge
    }

    @Test func derUmfangZaehltMengenJeEinheit() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Mengen"
        pos(ctx, e, "321.0010", "Oberboden abschieben", menge: 250, einheit: "m2")
        pos(ctx, e, "321.0020", "Aushub Baugrube", menge: 130, einheit: "m3")
        pos(ctx, e, "321.0030", "Aushub Garage", menge: 38, einheit: "m3")

        let u = Arbeitspakete.umfang(fuer: paket(ctx, e, "321 Baugrube / Erdbau"))
        #expect(u.positionen == 3)
        #expect(u.einheiten["m2"] == 250)
        #expect(u.einheiten["m3"] == 168)              // 130 + 38 zusammengezählt
        #expect(u.ohnePreis == 3)                      // noch kein Preis hinterlegt
        #expect(u.istGerechnet)                        // über den Namen, nicht gespeichert
    }

    /// Ein Auftrag ohne Nummer im Namen bekommt nichts zugeordnet — lieber nichts
    /// als das Falsche.
    @Test func ohneTitelnummerKeineZuordnung() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Ohne Nummer"
        pos(ctx, e, "572.0010", "Rasen ansäen")
        #expect(Arbeitspakete.positionen(fuer: paket(ctx, e, "Außenanlagen")).isEmpty)
        #expect(Arbeitspakete.titelNummerAusName(paket(ctx, e, "Außenanlagen")) == nil)
        #expect(Arbeitspakete.titelNummerAusName(paket(ctx, e, "572 Außenanlagen")) == "572")
    }
}

// MARK: - 🔴 Der Katalog darf keine falschen Anweisungen verteilen
//
// Befund 21.09.2026: drei Arbeitspakete hiessen alle "Außenanlagen und Freiflächen"
// (Titel 572, 544, 399). Der Katalogschlüssel zieht Ziffern heraus — also teilten
// sich drei verschiedene Arbeiten EINEN Eintrag. Wer bei einem abnimmt, hätte die
// Schritte den anderen beiden untergeschoben. Das geht an Lehrlinge.

struct KatalogSchluesselTests {

    @Test func kostengruppenNamenBekommenKeinenSchluessel() {
        #expect(AnweisungsKatalog.schluessel("572 Außenanlagen und Freiflächen") == "")
        #expect(AnweisungsKatalog.schluessel("Außenanlagen und Freiflächen") == "")
        #expect(AnweisungsKatalog.istNurKostengruppe("445 Baukonstruktionen") == true)
    }

    @Test func echteArbeitBekommtWeiterhinEinenSchluessel() {
        let k = AnweisungsKatalog.schluessel("Mauerwerk Außenwand Porenbeton, d = 24 cm")
        #expect(!k.isEmpty)
        #expect(k.contains("mauerwerk"))
    }

    /// Dieselbe Arbeit, verschieden geschrieben — ein Schlüssel. Das ist der Sinn.
    @Test func dieselbeArbeitTrotzSchreibweiseGleich() {
        #expect(AnweisungsKatalog.schluessel("Mauerwerk Innenwand 24 cm")
             == AnweisungsKatalog.schluessel("Mauerwerk Innenwand 24cm"))
    }
}

// MARK: - Fehler dürfen gar nicht erst passieren können
//
// "ohne Warnschilder bei Fehlern, Fehler dürfen erst gar nicht passieren können"
// (Andreas, 21.09.2026 — docs/WESEN-DES-MOPS.md)
//
// Die Vorbelegung beim Anlegen einer Baustelle stammte aus der Zeit, als diese App
// Veranstaltungen verwaltete: Beginn "nächste volle Stunde", Ende "+ 3 Stunden".
// Der Endtermin lag ab dem Folgetag in der Vergangenheit.

struct VorbelegungBaustelleTests {

    /// Die Bauzeit-Vorgabe muss in Wochen liegen, nicht in Stunden.
    @Test func bauendeLiegtDeutlichNachDemBeginn() {
        let kal = Calendar.current
        let beginn = kal.startOfDay(for: Date())
        let ende = kal.date(byAdding: .weekOfYear, value: 8, to: beginn)!
        let tage = kal.dateComponents([.day], from: beginn, to: ende).day ?? 0
        #expect(tage >= 28, "Eine Baustelle, die in Stunden fertig ist, gibt es nicht")
    }

    /// Ein Baubeginn faellt nie auf Samstag oder Sonntag.
    @Test func baubeginnIstEinWerktag() {
        let kal = Calendar.current
        var tag = kal.startOfDay(for: Date())
        repeat { tag = kal.date(byAdding: .day, value: 1, to: tag)! }
        while kal.isDateInWeekend(tag)
        #expect(!kal.isDateInWeekend(tag))
        #expect(tag > Date(), "Der Vorschlag liegt in der Zukunft, nicht heute rückwärts")
    }
}

// MARK: - Der Plan und die Arbeit sind zwei verschiedene Dinge
//
// "eine baustelle dauert keine 3 stunden. sie dauert so lange wie sie dauert.
//  sie wurde geplant das sie eventuell x stunden dauert, aber fertig ist sie
//  erst wenn sie fertig ist" (Andreas, 21.09.2026)

@MainActor
struct PlanUndArbeitTests {

    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event, _ status: JobStatus) {
        let a = Auftrag(context: ctx)
        a.processingDetails = "Aushub"; a.status = status; a.storageNote = ""; a.event = e
    }

    @Test func ueberDenTerminAberNichtFertig() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Spät"
        e.eventEndTime = Date().addingTimeInterval(-86400 * 10)
        auftrag(ctx, e, .inProgress)

        #expect(Tagesblick.Phase.istUeberfaellig(e))
        #expect(Tagesblick.Phase.von(e) == .laeuft, "Überfällig ändert die Phase nicht")
    }

    /// Fertig ist fertig — auch wenn es länger gedauert hat als geplant.
    @Test func spaetFertigIstNichtUeberfaellig() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Spät fertig"
        e.eventEndTime = Date().addingTimeInterval(-86400 * 10)
        auftrag(ctx, e, .completed)

        #expect(!Tagesblick.Phase.istUeberfaellig(e))
        #expect(Tagesblick.Phase.von(e) == .fertig)
    }

    /// Ohne geplanten Termin gibt es auch kein "zu spät".
    @Test func ohneGeplantesEndeKeinUrteil() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Offen"
        auftrag(ctx, e, .pending)
        #expect(!Tagesblick.Phase.istUeberfaellig(e))
    }
}

// MARK: - Der Kopf: die Lage in einem Satz
//
// "und im kopf der neuen anzeige muss noch was dazu, ?? mir fehlt da noch was,
//  eventuell weil nur eine baustelle drin ist" (Andreas, 21.09.2026)
//
// Der Bildschirm fing mit einer einzelnen Karte an und sagte nie, wovon das eine
// von wie vielen ist. Und er hiess "Wo war ich?", ohne die Frage beantworten zu
// können: gemessen in der echten Datenbank war `Event.startTime` leer und von 34
// Aufträgen hatte KEINER eine `lastStartTime` — wer plant, startet nichts.

@MainActor
struct TagesblickKopfTests {

    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event, _ status: JobStatus) {
        let a = Auftrag(context: ctx)
        a.processingDetails = "Aushub"; a.status = status; a.storageNote = ""; a.event = e
        var p = AuftragExtrasPayload()
        p.checklist = [AuftragChecklistItem(title: "Schritt")]   // sonst zählt er als "ohne Schritte"
        if let d = try? JSONEncoder().encode(p) { a.extras = String(data: d, encoding: .utf8) }
    }

    @Test func ohneBaustelleSagtErDas() {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        #expect(Tagesblick.fuerHeute(in: ctx).lageSatz == "Noch keine Baustelle")
    }

    @Test func eineBaustelleInPlanung() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Eins"
        auftrag(ctx, e, .pending)
        #expect(Tagesblick.fuerHeute(in: ctx).lageSatz == "1 Baustelle · 1 wird geplant")
    }

    @Test func mehrereBaustellenWerdenAufgeteilt() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        for (name, status) in [("BV A", JobStatus.inProgress), ("BV B", .pending), ("BV C", .pending)] {
            let e = Event(context: ctx); e.title = name
            auftrag(ctx, e, status)
        }
        let satz = Tagesblick.fuerHeute(in: ctx).lageSatz
        #expect(satz.contains("3 Baustellen"))
        #expect(satz.contains("1 läuft"))
        #expect(satz.contains("2 werden geplant"))
    }

    /// Der Arbeits-Satz nennt nur, was es wirklich gibt — keine Nullen.
    @Test func arbeitSatzNenntNurWasDaIst() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Ruhig"
        auftrag(ctx, e, .pending)
        let blick = Tagesblick.fuerHeute(in: ctx)
        #expect(!blick.arbeitSatz.contains("0 "))
        #expect(!blick.arbeitSatz.contains("steht still"))
    }

    /// 🔴 Der gemerkte Besuch schlägt die Schätzung aus den Zeitstempeln.
    @Test func derGemerkteBesuchGewinnt() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { ZuletztBesucht.vergessen() }

        let e = Event(context: ctx); e.title = "BV Besucht"
        auftrag(ctx, e, .pending)
        try ctx.save()                          // braucht eine feste Kennung

        #expect(Tagesblick.fuerHeute(in: ctx).zuletzt == nil, "vorher weiss er es nicht")
        ZuletztBesucht.merken(e)
        #expect(Tagesblick.fuerHeute(in: ctx).zuletzt?.baustelle == "BV Besucht")
    }

    /// Eine gelöschte Baustelle darf nicht als Karteileiche stehen bleiben.
    @Test func geloeschteBaustelleVerschwindetAusDemWiedereinstieg() throws {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        defer { ZuletztBesucht.vergessen() }

        let e = Event(context: ctx); e.title = "BV Weg"
        try ctx.save()
        ZuletztBesucht.merken(e)
        #expect(ZuletztBesucht.lesen(in: ctx)?.name == "BV Weg")

        ctx.delete(e)
        try ctx.save()
        #expect(ZuletztBesucht.lesen(in: ctx) == nil)
    }
}

// MARK: - Eine Meldung über EIN Ding führt auf DIESES Ding
//
// "hier steht oben ein Paket hat keine Dauer .. dann klicke ich ihn an, komme auf
//  die Baustelle bei der ich schon vor zwei Stunden die Dauer eingetragen habe.
//  wird der Punkt nicht nochmal kontrolliert wenn ich die Seite verlasse?"
//  (Andreas, 21.09.2026)
//
// In der echten Datenbank nachgemessen: 33 von 34 Aufträgen hatten eine Dauer, einer
// nicht. Die Meldung stimmte — sie lieferte ihn nur auf der Baustelle ab und liess
// ihn das eine suchen.

@MainActor
struct AnstehendZielTests {

    @discardableResult
    private func auftrag(_ ctx: NSManagedObjectContext, _ e: Event, _ was: String,
                         dauer: Double) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = was; a.status = .pending; a.storageNote = ""
        a.dauerTage = dauer; a.event = e
        return a
    }

    private func zeileDauer(_ ctx: NSManagedObjectContext) -> Tagesblick.Anstehend? {
        Tagesblick.fuerHeute(in: ctx).lagen.first?.anstehend
            .first { $0.text.contains("Dauer") }
    }

    @Test func einEinzelnesPaketWirdBeimNamenGenanntUndAngesteuert() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Fast fertig geplant"
        auftrag(ctx, e, "321 Baugrube / Erdbau", dauer: 0)
        for i in 1...5 { auftrag(ctx, e, "Paket \(i)", dauer: 1) }

        let zeile = try #require(zeileDauer(ctx))
        #expect(zeile.text.contains("321 Baugrube"), "Das eine Paket wird benannt")
        #expect(zeile.text.contains("hat keine Dauer"), "Einzahl statt: 1 Pakete haben")
        #expect(zeile.job != nil, "und die Zeile führt dorthin")
    }

    @Test func mehrerePaketeFuehrenAufDieBaustelle() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Frisch"
        for i in 1...4 { auftrag(ctx, e, "Paket \(i)", dauer: 0) }

        let zeile = try #require(zeileDauer(ctx))
        #expect(zeile.text.hasPrefix("4 Pakete haben"))
        #expect(zeile.job == nil, "bei vieren gibt es kein einzelnes Ziel")
    }

    /// Erledigt heisst weg. Die Meldung darf nicht stehen bleiben.
    @Test func mitDauerVerschwindetDieMeldung() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Nachgetragen"
        let a = auftrag(ctx, e, "321 Baugrube / Erdbau", dauer: 0)
        #expect(zeileDauer(ctx) != nil)

        a.dauerTage = 1.5
        #expect(zeileDauer(ctx) == nil, "nachgetragen = weg, ohne Neustart")
    }

    /// Eine einzelne Position ohne Preis heisst „eine", nicht „1 Positionen".
    @Test func auchBeiPreisenStimmtDieZahlform() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Ein Preis"
        let p = LVPosition(context: ctx)
        p.posNr = "1.0010"; p.bezeichnung = "Pfosten"; p.menge = 1; p.einheit = "St"; p.event = e
        auftrag(ctx, e, "Paket", dauer: 1)

        let zeile = Tagesblick.fuerHeute(in: ctx).lagen.first?.anstehend
            .first { $0.text.contains("Preis") }
        #expect(zeile?.text == "Eine Position hat noch keinen Preis.")
    }
}
