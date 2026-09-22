//
//  SchrittPassungTests.swift
//
//  "ich brauche keinen Bauzaun und Dixiklo für einen pfosten den ich setze"
//  (Andreas, 21.09.2026)
//
//  Vorschläge sind für die grosse Baustelle geschrieben. Der Mops vergleicht sie
//  gegen das, was auf DIESER Baustelle im LV steht — und wählt ab, was nicht
//  gekauft wurde. Abwählen, nicht wegwerfen: ein Griff, und es ist wieder drin.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct SchrittPassungTests {

    private let kleineBaustelle = "pfosten setzen beton c25/30 aushub grube"
    private let grosseBaustelle = "baustelle einrichten bauzaun 120 m fassadengerüst "
                                + "baustellentoilette dixi container aushub baugrube"

    @Test func bauzaunFehltAufDerKleinenBaustelle() {
        #expect(SchrittPassung.fehltImLV("Bauzaun aufstellen und sichern",
                                         lvWortschatz: kleineBaustelle) == "Bauzaun")
    }

    @Test func aufDerGrossenBaustelleIstErGekauft() {
        #expect(SchrittPassung.fehltImLV("Bauzaun aufstellen und sichern",
                                         lvWortschatz: grosseBaustelle) == nil)
    }

    @Test func gewoehnlicheArbeitWirdNieAbgewaehlt() {
        for schritt in ["Aushub herstellen, Sohle verdichten",
                        "Pfosten lotrecht ausrichten",
                        "Beton C25/30 einbringen und verdichten",
                        "Oberboden abschieben und seitlich lagern"] {
            #expect(SchrittPassung.fehltImLV(schritt, lvWortschatz: kleineBaustelle) == nil,
                    "\(schritt) darf nicht abgewählt werden")
        }
    }

    /// 🔴 Ohne LV gibt es kein Urteil. Ein leeres Leistungsverzeichnis heisst
    /// "wir wissen es nicht", nicht "kommt nicht vor".
    @Test func ohneLVKeinUrteil() {
        #expect(SchrittPassung.fehltImLV("Bauzaun aufstellen", lvWortschatz: "") == nil)
    }

    @Test func mehrereSachenWerdenErkannt() {
        #expect(SchrittPassung.fehltImLV("Baustellentoilette aufstellen",
                                         lvWortschatz: kleineBaustelle) == "Baustellentoilette")
        #expect(SchrittPassung.fehltImLV("Fassadengerüst stellen lassen",
                                         lvWortschatz: kleineBaustelle) == "Gerüst")
        #expect(SchrittPassung.fehltImLV("Baustrom anmelden",
                                         lvWortschatz: kleineBaustelle) == "Baustrom")
    }

    /// Der Katalog darf nur Dinge enthalten, die wirklich eine eigene Position sind —
    /// jeder Eintrag kann einen Arbeitsschritt abwählen.
    @Test func derKatalogBleibtKlein() {
        #expect(SchrittPassung.eigenePosition.count <= 15)
        #expect(SchrittPassung.eigenePosition.allSatisfy { !$0.stamm.isEmpty })
    }

    @MainActor
    @Test func ueberDasEchteLVDerBaustelle() throws {
        let ctx = PersistenceController(inMemory: true).container.viewContext
        let e = Event(context: ctx); e.title = "BV Pfosten"
        let p = LVPosition(context: ctx)
        p.posNr = "1.0010"; p.bezeichnung = "Pfosten setzen, einbetonieren"
        p.menge = 1; p.einheit = "St"; p.event = e

        let a = Auftrag(context: ctx)
        a.processingDetails = "1 Pfosten setzen"; a.status = .pending
        a.storageNote = ""; a.event = e

        let schritte = [AnweisungsSchritt(text: "Bauzaun aufstellen", herkunft: .prof),
                        AnweisungsSchritt(text: "Grube ausheben", herkunft: .prof)]
        let treffer = SchrittPassung.fehlende(in: schritte, auftrag: a)
        #expect(treffer.count == 1)
        #expect(treffer[schritte[0].id] == "Bauzaun")
        #expect(treffer[schritte[1].id] == nil)
    }
}
