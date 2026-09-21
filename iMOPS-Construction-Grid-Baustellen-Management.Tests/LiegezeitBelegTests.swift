//
//  LiegezeitBelegTests.swift
//
//  "wenn auf dem zement steht er braucht 2 tage, dann braucht er 2 tage, wenn der
//   chef anders entscheidet, dann muss das doch dokumentiert werden. der mops
//   schreibt ja nicht umsonst 2 tage" (Andreas, 21.09.2026)
//
//  Die Richtung: nicht der Katalog ist das Maß, sondern der BELEG. Und was zählt,
//  ist die Herkunft der Zahl — die stand nirgends.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LiegezeitBelegTests {

    private func frisch() -> LiegezeitBuch {
        LiegezeitBuch.shared.leeren()
        return LiegezeitBuch.shared
    }

    private func datenblatt(_ tage: Double, id: String = "k1") -> LiegezeitBeleg {
        LiegezeitBeleg(id: id, tage: tage, herkunft: .datenblatt,
                       quelle: "CEM I 42,5 R, Merkblatt S. 2", von: "Andreas")
    }

    /// 🔴 Der Kern: steht auf dem Sack 2 Tage, schweigt der Katalog mit seinen 3.
    @Test func derBelegSchlaegtDenRichtwert() {
        let buch = frisch(); defer { buch.leeren() }
        buch.merken(datenblatt(2))

        let lage = buch.lage(kanteID: "k1", eingetragen: 2, nachVorgaenger: "Beton härten Decke")
        #expect(lage == .belegtUndEingehalten(datenblatt(2)) || {
            if case .belegtUndEingehalten = lage { return true }; return false
        }(), "2 belegte Tage sind richtig, auch wenn der Katalog 3 kennt")

        if case .nurRichtwert = lage { Issue.record("Der Katalog darf hier nicht mehr reden") }
    }

    /// Ohne Beleg bleibt der Katalog ein Vorschlag.
    @Test func ohneBelegRedetDerKatalog() {
        let buch = frisch(); defer { buch.leeren() }
        let lage = buch.lage(kanteID: "k-neu", eingetragen: 2, nachVorgaenger: "Beton härten")
        if case .nurRichtwert(let z) = lage {
            #expect(z.katalog.tage == 3)
        } else {
            Issue.record("Ohne Beleg soll der Richtwert kommen")
        }
    }

    /// 🔴 Der Fall, um den es geht: jemand geht unter den Beleg, ohne etwas zu sagen.
    @Test func unterDemBelegOhneGrundWirdGemeldet() {
        let buch = frisch(); defer { buch.leeren() }
        buch.merken(datenblatt(2))

        let lage = buch.lage(kanteID: "k1", eingetragen: 1, nachVorgaenger: "Beton härten")
        if case .unterschrittenOhneGrund(let b, let jetzt) = lage {
            #expect(b.tage == 2)
            #expect(jetzt == 1)
        } else {
            Issue.record("Unter einem Beleg muss der Mops etwas sagen")
        }
    }

    /// Ist die Entscheidung dokumentiert, steht sie da — mit Namen, nicht als Vorwurf.
    @Test func dokumentierteEntscheidungBleibtStehen() {
        let buch = frisch(); defer { buch.leeren() }
        var e = LiegezeitBeleg(id: "k1", tage: 1, herkunft: .entschieden,
                               von: "Chef")
        e.stattBelegTage = 2
        e.begruendung = "Schalung wird nur seitlich entfernt, Decke bleibt gestützt"
        buch.merken(e)

        if case .unterschritten(let b) = buch.lage(kanteID: "k1", eingetragen: 1,
                                                    nachVorgaenger: "Beton härten") {
            #expect(b.istUnterschreitung)
            #expect(b.von == "Chef")
            #expect(b.begruendung.contains("gestützt"))
        } else {
            Issue.record("Die dokumentierte Entscheidung muss sichtbar bleiben")
        }
        #expect(buch.unterschreitungen.count == 1, "und sie steht in der Liste fürs Archiv")
    }

    /// Was belegt ist, ist belegt — Erfahrung und Katalog sind es nicht.
    @Test func nurDatenblattUndStatikerSindBelegt() {
        #expect(LiegezeitHerkunft.datenblatt.istBelegt)
        #expect(LiegezeitHerkunft.statiker.istBelegt)
        #expect(!LiegezeitHerkunft.erfahrung.istBelegt)
        #expect(!LiegezeitHerkunft.katalog.istBelegt)
        #expect(!LiegezeitHerkunft.entschieden.istBelegt)
    }

    /// Der Richtwert des Mops braucht keinen Namen — alles andere schon.
    @Test func wasNichtAbgelesenIstBrauchtEinenNamen() {
        #expect(!LiegezeitHerkunft.katalog.brauchtNamen)
        for h in [LiegezeitHerkunft.datenblatt, .statiker, .erfahrung, .entschieden] {
            #expect(h.brauchtNamen, "\(h.rawValue) ohne Namen ist wertlos")
        }
    }

    /// Wer MEHR einplant als belegt, hört nichts. Vorsicht ist kein Fehler.
    @Test func laengerAlsBelegtIstInOrdnung() {
        let buch = frisch(); defer { buch.leeren() }
        buch.merken(datenblatt(2))
        if case .belegtUndEingehalten = buch.lage(kanteID: "k1", eingetragen: 5,
                                                   nachVorgaenger: "Beton härten") {
        } else {
            Issue.record("Länger warten ist nie ein Problem")
        }
    }
}
