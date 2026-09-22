//
//  PaketTeilenTests.swift
//
//  "Sind im oberen Bereich die ganzen Anforderungen mit den Arbeitsschritten passend?
//   Passt oben und unten zusammen?" (Andreas, 22.09.2026)
//
//  Sie passten nicht: "411 Abwasser-, Wasser-, Gasanlagen" enthielt einen
//  Schmutzwasser-Hausanschluss in 2,60 m Tiefe UND die Sanitärinstallation im
//  Dachgeschoss. Ursache: Arbeitspakete gruppieren nach Titelnummer, und die folgt
//  der DIN 276 — einer KOSTENgliederung, keiner Ablaufgliederung.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct SchrittPassungRueckrichtungTests {

    /// 🔴 Sein echter Fall, Zeile für Zeile.
    private let schritte = [
        "Rohrleitungen vormontieren", "Wandschlitze / Kernbohrungen",
        "Leitungen verlegen (Warm/Kalt/Abwasser)", "Druckpruefung durchfuehren",
        "Daemmung anbringen", "Sanitaerobjekte montieren",
        "Dichtheitspruefung / Abnahme", "Dokumentation + Fotos",
    ]

    private func pos(_ ctx: NSManagedObjectContext, _ e: Event, _ nr: String,
                     _ bez: String) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = nr; p.bezeichnung = bez; p.menge = 10; p.einheit = "m"; p.event = e
        return p
    }

    private func bau() -> (NSManagedObjectContext, Event, Auftrag) {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Setiadji"
        let a = Auftrag(context: ctx)
        a.processingDetails = "411 Abwasser-, Wasser-, Gasanlagen"
        a.status = .pending; a.storageNote = ""; a.event = e
        return (ctx, e, a)
    }

    /// Der Hausanschluss im Graben taucht in keinem Schritt auf.
    @Test func derHausanschlussWirdGemeldet() {
        let (ctx, e, a) = bau()
        pos(ctx, e, "411.0010", "Schmutzwasser-Hausanschluss PP DN 150 bis Schacht (T 2,60 m)")
        let fehlend = SchrittPassung.ohneSchritt(auftrag: a, schritte: schritte)
        #expect(fehlend.count == 1)
        #expect(fehlend.first?.posNr == "411.0010")
    }

    /// 🔴 ä und ae sind dasselbe Wort: „Sanitärinstallation" gilt als abgedeckt,
    /// weil ein Schritt „Sanitaerobjekte montieren" heisst. Ohne das hätte der Mops
    /// zwei Positionen gemeldet, die längst erledigt sind.
    @Test func umlautUndUmschreibungSindDasselbe() {
        let (ctx, e, a) = bau()
        pos(ctx, e, "411.0060", "Sanitärinstallation Bad DG (10,26 m2)")
        #expect(SchrittPassung.ohneSchritt(auftrag: a, schritte: schritte).isEmpty)
    }

    /// Wortstamm-Nähe reicht — „Dichtheitspruefung Grundleitungen" ist abgedeckt.
    @Test func derWortstammGenuegt() {
        let (ctx, e, a) = bau()
        pos(ctx, e, "411.0035", "Dichtheitspruefung Grundleitungen nach DIN EN 1610")
        #expect(SchrittPassung.ohneSchritt(auftrag: a, schritte: schritte).isEmpty)
    }

    /// Ohne Schritte wird gar nichts gemeldet — dafür gibt es das eigene Band.
    @Test func ohneSchritteKeineMeldung() {
        let (ctx, e, a) = bau()
        pos(ctx, e, "411.0010", "Schmutzwasser-Hausanschluss PP DN 150")
        let fehlend = SchrittPassung.ohneSchritt(auftrag: a, schritte: [])
        #expect(fehlend.count == 1)   // ohne Schritte ist alles unabgedeckt;
        // die Ansicht zeigt es nur nicht, weil dann das Anweisungs-Band greift.
    }

    /// Eine Position ohne Text bekommt kein Urteil.
    @Test func ohneTextKeinUrteil() {
        let (ctx, e, a) = bau()
        let p = pos(ctx, e, "411.0099", "")
        p.bezeichnung = nil
        #expect(SchrittPassung.ohneSchritt(auftrag: a, schritte: schritte).isEmpty)
    }
}

@MainActor
struct PaketTeilenTests {

    private func bau() -> (NSManagedObjectContext, Event, Auftrag) {
        PaketZuordnung.shared.leeren()
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Teilen"
        let a = Auftrag(context: ctx)
        a.processingDetails = "411 Abwasser-, Wasser-, Gasanlagen"
        a.status = .pending; a.storageNote = ""; a.event = e
        for (nr, bez) in [("411.0010", "Schmutzwasser-Hausanschluss PP DN 150 (T 2,60 m)"),
                          ("411.0030", "Grundleitungen KG DN 100 frostfrei"),
                          ("411.0055", "Kontrollschächte setzen"),
                          ("411.0060", "Sanitärinstallation Bad DG"),
                          ("411.0070", "Sanitärinstallation WC EG")] {
            let p = LVPosition(context: ctx)
            p.posNr = nr; p.bezeichnung = bez; p.menge = 5; p.einheit = "m"; p.event = e
        }
        return (ctx, e, a)
    }

    /// 🔴 Der Mops erkennt die Trennlinie zwischen Erdreich und Innenausbau —
    /// und sagt dazu, dass es geraten ist.
    @Test func derVorschlagTrenntErdarbeiten() throws {
        let (_, _, a) = bau(); defer { PaketZuordnung.shared.leeren() }
        let t = try #require(Arbeitspakete.teilungsVorschlag(fuer: a))
        #expect(t.abtrennen.count == 3, "Hausanschluss, Grundleitungen, Schächte")
        #expect(t.name.contains("Erdarbeiten"))
        #expect(t.begruendung.contains("Erdreich"))
    }

    /// Wo alles zusammengehört, gibt es keinen Vorschlag.
    @Test func ohneTrennlinieKeinVorschlag() {
        PaketZuordnung.shared.leeren(); defer { PaketZuordnung.shared.leeren() }
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Einheitlich"
        let a = Auftrag(context: ctx)
        a.processingDetails = "342 Mauerwerk Innenwand"
        a.status = .pending; a.storageNote = ""; a.event = e
        for nr in ["342.0010", "342.0020", "342.0030"] {
            let p = LVPosition(context: ctx)
            p.posNr = nr; p.bezeichnung = "Mauerwerk Innenwand Ytong PP 4-0,55"
            p.menge = 20; p.einheit = "m2"; p.event = e
        }
        #expect(Arbeitspakete.teilungsVorschlag(fuer: a) == nil)
    }

    /// 🔴 Nach dem Teilen steht keine Position mehr in BEIDEN Paketen.
    @Test func nachDemTeilenKeineDoppelten() throws {
        let (ctx, e, alt) = bau(); defer { PaketZuordnung.shared.leeren() }
        try ctx.save()

        let neu = Auftrag(context: ctx)
        neu.processingDetails = "411a Erdarbeiten und Anschlüsse"
        neu.status = .pending; neu.storageNote = ""; neu.event = e
        try ctx.save()

        PaketZuordnung.shared.setzen(["411.0010", "411.0030", "411.0055"], fuer: neu)
        PaketZuordnung.shared.setzen(["411.0060", "411.0070"], fuer: alt)

        let imNeuen = Arbeitspakete.positionen(fuer: neu).compactMap(\.posNr)
        let imAlten = Arbeitspakete.positionen(fuer: alt).compactMap(\.posNr)
        #expect(imNeuen.count == 3)
        #expect(imAlten.count == 2)
        #expect(Set(imNeuen).isDisjoint(with: Set(imAlten)), "keine Position in beiden")
    }

    /// Ein ungeteiltes Paket sammelt weiter über die Titelnummer.
    @Test func ohneTeilungGiltWeiterDieTitelnummer() throws {
        let (ctx, _, a) = bau(); defer { PaketZuordnung.shared.leeren() }
        try ctx.save()
        #expect(Arbeitspakete.positionen(fuer: a).count == 5)
    }
}
