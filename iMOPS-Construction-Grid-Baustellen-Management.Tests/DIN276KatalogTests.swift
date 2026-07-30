//
//  DIN276KatalogTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//
//  Sichert die EINE Quelle der Wahrheit für DIN-276-Kostengruppen ab:
//  der flache Katalog ist eine abgeleitete Sicht auf DIN276BaumKatalog, und
//  DIN276KostenGruppe.bezeichnung(fuer:) ist die einzige Stelle, die Namen kennt.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct DIN276KatalogTests {

    // MARK: - Abgeleiteter Katalog

    @Test func flacherKatalogIstAusDemBaumAbgeleitet() {
        // Der Baum hat drei Ebenen; die alte handgepflegte Liste hatte 114 Einträge.
        #expect(DIN276KostenGruppe.alle.count > 300)

        // Keine Nummer doppelt — sonst gewinnt beim Lookup der Zufall.
        let nummern = DIN276KostenGruppe.alle.map(\.nummer)
        #expect(Set(nummern).count == nummern.count)

        // Aufsteigend sortiert (der Picker gruppiert per Präfix und verlässt sich darauf).
        #expect(nummern == nummern.sorted())
    }

    @Test func katalogUndBaumSagenDasselbe() {
        // Jede Nummer im flachen Katalog muss im Baum mit derselben Bezeichnung stehen.
        // Genau hier sind die beiden Kataloge früher auseinandergelaufen.
        func sammle(_ knoten: [DIN276BaumKnoten]) -> [String: String] {
            knoten.reduce(into: [String: String]()) { acc, k in
                acc[k.nummer] = k.bezeichnung
                acc.merge(sammle(k.kinder)) { a, _ in a }
            }
        }
        let baum = sammle(DIN276BaumKatalog.hauptgruppen)
        for eintrag in DIN276KostenGruppe.alle {
            #expect(baum[eintrag.nummer] == eintrag.bezeichnung,
                    "KG \(eintrag.nummer) weicht ab")
        }
    }

    // MARK: - Namens-Auflösung (die fünf ehemaligen switch-Kopien)

    @Test func dreistelligeKGsHabenEinenNamen() {
        // Vorher fielen ALLE dreistelligen Nummern in „Sonstige", weil die
        // switch-Kopien nur Hunderter und Zehner kannten.
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "534") == "Stellplätze")
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "331") == "Tragende Außenwände")
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "541") == "Einfriedungen")
    }

    @Test func veralteteUndFalscheNamenSindWeg() {
        // 200 hieß in den Kopien „Herrichten & Erschließen" (alte DIN-Fassung).
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "200") == "Vorbereitende Maßnahmen")
        // 380 stand dort als „Fenster & Türen" — das war in keiner Fassung richtig.
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "380") == "Baukonstruktive Einbauten")
    }

    @Test func nachgezogeneKG532IstDa() {
        // Der Baum sprang früher von 531 auf 533; die Automatik vergab aber 532.
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "532") == "Straßen")
        #expect(DIN276KostenGruppe.alle.contains { $0.nummer == "532" })
    }

    @Test func unbekannteNummerFaelltAufSonstige() {
        // Hauseigene Gliederungsnummern sollen nicht wie ein Fehler aussehen.
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "999") == "Sonstige")
        #expect(DIN276KostenGruppe.bezeichnung(fuer: "") == "Sonstige")
    }
}
