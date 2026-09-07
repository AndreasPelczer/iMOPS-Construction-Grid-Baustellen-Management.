//
//  BautagesberichtTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//
//  Bautagesbericht als Datensatz — Entity, Relation, eingefrorene Zählstände.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BautagesberichtTests {

    /// Eigener In-Memory-Stack je Test, wie in AufmassTests — die Suite-Struct
    /// wird pro @Test neu erzeugt, damit sind die Tests vollständig isoliert.
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func makeEvent(titel: String = "Testbaustelle") -> Event {
        let e = Event(context: ctx)
        e.title = titel
        e.timeStamp = Date()
        return e
    }

    @MainActor
    private func makeMangel(_ event: Event, titel: String) -> Mangel {
        let m = Mangel(context: ctx)
        m.id = UUID()
        m.titel = titel
        m.erfasstAm = Date()
        event.addToMaengel(m)
        return m
    }

    /// Legt einen Bericht an und friert die Zählstände ein — dieselbe Reihenfolge
    /// wie `BautagesberichtView.berichtSpeichern()`.
    @MainActor
    private func makeBericht(_ event: Event, datum: Date = Date()) throws -> Bautagesbericht {
        let auftraege = (event.jobs?.allObjects as? [Auftrag]) ?? []
        let maengel   = (event.maengel?.allObjects as? [Mangel]) ?? []
        let lv        = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []

        let b = Bautagesbericht(context: ctx)
        b.id = UUID()
        b.datum = datum
        b.erstelltAm = Date()
        b.witterung = "bewölkt"
        b.ausgefuehrteArbeiten = "Wände gemauert"
        b.personalAnzahl = 4
        b.snapAuftraegeGesamt = Int16(auftraege.count)
        b.snapAuftraegeOffen  = Int16(auftraege.filter { !$0.isCompleted }.count)
        b.snapLVPositionen    = Int16(lv.count)
        b.snapMaengel         = Int16(maengel.count)
        event.addToBautagesberichte(b)
        try ctx.save()
        return b
    }

    // MARK: - Entity und Relation

    /// Der Core-Data-Stack lädt mit der neuen Entity, und ein Bericht lässt sich
    /// anlegen, speichern und wieder laden.
    @MainActor
    @Test func berichtLaesstSichSpeichernUndLaden() throws {
        let event = makeEvent()
        let b = try makeBericht(event)
        let id = try #require(b.id)

        let req = Bautagesbericht.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let gefunden = try ctx.fetch(req)

        #expect(gefunden.count == 1)
        #expect(gefunden.first?.ausgefuehrteArbeiten == "Wände gemauert")
        #expect(gefunden.first?.personalAnzahl == 4)
    }

    /// Die Inverse muss greifen. Stimmt `inverseEntity` nicht, wirft Core Data
    /// keinen Fehler — die Liste bleibt einfach leer und der Zähler steht auf 0.
    @MainActor
    @Test func relationGreiftInBeideRichtungen() throws {
        let event = makeEvent()
        let b = try makeBericht(event)

        #expect(b.event === event)
        let berichte = (event.bautagesberichte?.allObjects as? [Bautagesbericht]) ?? []
        #expect(berichte.count == 1)
        #expect(berichte.first?.id == b.id)
    }

    // MARK: - Der eigentliche Punkt: die Zahlen stehen still

    /// **Der Kern des Ganzen.** Ein Bericht dokumentiert seinen Tag. Kommt danach
    /// ein Mangel dazu, darf der alte Bericht davon nichts wissen — sonst schreibt
    /// die App still die Vergangenheit um.
    @MainActor
    @Test func spaetererMangelAendertDenAltenBerichtNicht() throws {
        let event = makeEvent()
        makeMangel(event, titel: "Riss im Putz")
        makeMangel(event, titel: "Fuge offen")
        try ctx.save()

        let bericht = try makeBericht(event)
        #expect(bericht.snapMaengel == 2)

        // Am nächsten Tag kommt ein Mangel dazu.
        makeMangel(event, titel: "Farbe blättert")
        try ctx.save()

        // Die Baustelle hat jetzt drei — der Bericht von gestern zeigt weiter zwei.
        let jetzt = (event.maengel?.allObjects as? [Mangel])?.count ?? 0
        #expect(jetzt == 3)
        #expect(bericht.snapMaengel == 2)
    }

    /// Auch nach dem Neuladen aus dem Speicher bleibt die Zahl stehen —
    /// der Wert hängt am Datensatz, nicht an einem Objekt im Arbeitsspeicher.
    @MainActor
    @Test func eingefroreneZahlUeberlebtDenNeuladen() throws {
        let event = makeEvent()
        makeMangel(event, titel: "Erster")
        try ctx.save()

        let bericht = try makeBericht(event)
        let id = try #require(bericht.id)

        makeMangel(event, titel: "Zweiter")
        try ctx.save()
        ctx.refreshAllObjects()

        let req = Bautagesbericht.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let geladen = try #require(try ctx.fetch(req).first)

        #expect(geladen.snapMaengel == 1)
    }

    /// Mehrere Berichte an derselben Baustelle halten jeder ihren eigenen Stand.
    @MainActor
    @Test func jederBerichtHaeltSeinenEigenenStand() throws {
        let event = makeEvent()
        makeMangel(event, titel: "Tag 1")
        try ctx.save()
        let montag = try makeBericht(event, datum: Date(timeIntervalSince1970: 1_000_000))

        makeMangel(event, titel: "Tag 2")
        makeMangel(event, titel: "Tag 2b")
        try ctx.save()
        let dienstag = try makeBericht(event, datum: Date(timeIntervalSince1970: 1_086_400))

        #expect(montag.snapMaengel == 1)
        #expect(dienstag.snapMaengel == 3)
    }

    // MARK: - Sperre (Etappe 3 — Felder stehen schon)

    /// Ein frischer Bericht ist offen, ein freigegebener gesperrt.
    @MainActor
    @Test func gesperrtAmMachtDenBerichtUnveraenderlich() throws {
        let event = makeEvent()
        let b = try makeBericht(event)
        #expect(b.istGesperrt == false)

        b.gesperrtAm = Date()
        b.freigegebenVon = "Polier"
        try ctx.save()

        #expect(b.istGesperrt == true)
        #expect(b.istKorrektur == false)
    }

    /// Eine Korrektur ist ein NEUER Bericht mit Bezug — das Original bleibt.
    @MainActor
    @Test func korrekturZeigtAufDasOriginal() throws {
        let event = makeEvent()
        let original = try makeBericht(event)
        original.gesperrtAm = Date()
        try ctx.save()

        let korrektur = try makeBericht(event)
        korrektur.korrigiertVonID = original.id
        try ctx.save()

        #expect(korrektur.istKorrektur == true)
        #expect(korrektur.korrigiertVonID == original.id)

        // Beide sind da — nichts wurde überschrieben.
        let alle = try ctx.fetch(Bautagesbericht.fetchRequest())
        #expect(alle.count == 2)
    }
}
