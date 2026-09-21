//
//  SonderfallBuchTests.swift
//
//  Der „jaaa, des musst du so sehen"-Knopf (Andreas, 21.09.2026).
//
//  Zwei Wirkungen, und die zweite ist die eigentliche:
//  1. Der Mops hört auf, diese eine Sache zu melden — mit Erklärung, nicht stumm.
//  2. Er ZÄHLT. Dieselbe Ausnahme zum dritten Mal ist keine Ausnahme mehr.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct SonderfallBuchTests {

    private func frisch() -> SonderfallBuch {
        SonderfallBuch.shared.leeren()
        return SonderfallBuch.shared
    }

    private func fall(_ thema: String, baustelle: String = "BV A",
                      betrifft: String = "312 Baugrube", nurHier: Bool = true) -> Sonderfall {
        Sonderfall(thema: thema, wasDerMopsSagte: "Der Mops meckert",
                   wasGilt: "Läuft über den Pauschalposten", baustelle: baustelle,
                   betrifft: betrifft, von: "Andreas", nurHier: nurHier)
    }

    @Test func einErklaerterFallLaesstDenMopsSchweigen() {
        let buch = frisch()
        defer { buch.leeren() }
        #expect(buch.erklaerung(thema: "dauer-fehlt", baustelle: "BV A",
                                betrifft: "312 Baugrube") == nil)
        buch.eintragen(fall("dauer-fehlt"))
        #expect(buch.erklaerung(thema: "dauer-fehlt", baustelle: "BV A",
                                betrifft: "312 Baugrube") != nil)
    }

    /// 🔴 „nur hier" heisst nur hier. Eine Erklärung für die eine Baustelle darf nicht
    /// die andere stumm schalten — sonst verschwinden echte Lücken.
    @Test func nurHierGiltNichtAufDerNachbarbaustelle() {
        let buch = frisch()
        defer { buch.leeren() }
        buch.eintragen(fall("dauer-fehlt", baustelle: "BV A"))
        #expect(buch.erklaerung(thema: "dauer-fehlt", baustelle: "BV B",
                                betrifft: "312 Baugrube") == nil)
    }

    @Test func immerGiltUeberall() {
        let buch = frisch()
        defer { buch.leeren() }
        buch.eintragen(fall("dauer-fehlt", baustelle: "BV A", nurHier: false))
        #expect(buch.erklaerung(thema: "dauer-fehlt", baustelle: "BV Ganz woanders",
                                betrifft: "999 Irgendwas") != nil)
    }

    /// Die eigentliche Idee: zählen. Zwei Ausnahmen sind Ausnahmen, drei sind eine Regel.
    @Test func dreimalErklaertIstKeineAusnahmeMehr() {
        let buch = frisch()
        defer { buch.leeren() }
        buch.eintragen(fall("nicht-im-lv:Bauzaun", baustelle: "BV A"))
        buch.eintragen(fall("nicht-im-lv:Bauzaun", baustelle: "BV B"))
        #expect(buch.reifeThemen().isEmpty, "zwei sind noch eine Ausnahme")

        buch.eintragen(fall("nicht-im-lv:Bauzaun", baustelle: "BV C"))
        let reif = buch.reifeThemen()
        #expect(reif.count == 1)
        #expect(reif.first?.thema == "nicht-im-lv:Bauzaun")
        #expect(reif.first?.anzahl == 3)
    }

    @Test func verschiedeneThemenZaehlenGetrennt() {
        let buch = frisch()
        defer { buch.leeren() }
        for _ in 0..<3 { buch.eintragen(fall("dauer-fehlt")) }
        for _ in 0..<2 { buch.eintragen(fall("preis-fehlt")) }
        #expect(buch.anzahl(thema: "dauer-fehlt") == 3)
        #expect(buch.anzahl(thema: "preis-fehlt") == 2)
        #expect(buch.reifeThemen().map(\.thema) == ["dauer-fehlt"])
    }

    /// Die Erklärung überlebt — sie ist der Nachweis, nicht nur ein Stummschalter.
    @Test func dieErklaerungBleibtLesbar() {
        let buch = frisch()
        defer { buch.leeren() }
        buch.eintragen(fall("dauer-fehlt"))
        let gefunden = buch.erklaerung(thema: "dauer-fehlt", baustelle: "BV A",
                                       betrifft: "312 Baugrube")
        #expect(gefunden?.wasGilt == "Läuft über den Pauschalposten")
        #expect(gefunden?.von == "Andreas")
    }
}

// MARK: - Und die Wirkung im Tagesblick

@MainActor
struct SonderfallImTagesblickTests {

    @Test func erklaerteMeldungVerschwindetAusDerUebersicht() throws {
        SonderfallBuch.shared.leeren()
        defer { SonderfallBuch.shared.leeren() }

        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Erklärt"
        e.eventStartTime = Date()
        let a = Auftrag(context: ctx)
        a.processingDetails = "312 Baugrube / Erdbau"
        a.status = .pending; a.storageNote = ""; a.dauerTage = 0; a.event = e

        func meldung() -> Bool {
            Tagesblick.fuerHeute(in: ctx).lagen.first?.anstehend
                .contains { $0.text.contains("Dauer") } ?? false
        }
        #expect(meldung(), "vorher meldet der Mops die fehlende Dauer")

        SonderfallBuch.shared.eintragen(Sonderfall(
            thema: "dauer-fehlt", wasDerMopsSagte: "hat keine Dauer",
            wasGilt: "Wird im Stundenlohn abgerechnet", baustelle: "BV Erklärt",
            betrifft: "312 Baugrube / Erdbau", von: "Andreas"))

        #expect(!meldung(), "danach schweigt er — mit Grund, nicht stumm")
    }
}
