//
//  ProjektGeneratorTests.swift
//  Vom Haus-Generator zum Projekt-Generator — der kleine erste Schritt.
//
//  Prüft: der Haus-Weg bleibt unverändert, und die kleine Vorlage (Hofeinfahrt) liefert
//  denselben Ergebnis-Typ mit Massen + Phasen — damit die vier Reiter für beide laufen.
//  Reine Werte (kein Core Data, kein Netz).
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ProjektGeneratorTests {

    // MARK: - ProjektTyp: Haus vs. Vorlage

    @Test func projektTypUnterscheidetHausUndVorlage() {
        #expect(ProjektTyp.einfamilienhaus.istHaus)
        #expect(ProjektTyp.reihenhaus.istHaus)
        #expect(!ProjektTyp.hofeinfahrt.istHaus)
        #expect(ProjektTyp.einfamilienhaus.hausTyp == .einfamilienhaus)
        #expect(ProjektTyp.hofeinfahrt.hausTyp == nil)
        // Der Haus-Typ Hofeinfahrt taucht nicht als Haustyp auf — keine erfundene Taxonomie.
        #expect(ProjektTyp.allCases.contains(.hofeinfahrt))
    }

    // MARK: - Haus läuft unverändert

    @Test func hausTypLaeuftUeberDenHausGenerator() {
        let ausProjektGen = ProjektGenerator.generate(typ: .einfamilienhaus,
                                                      haus: HouseProject(), flaeche: 0)
        // Das Haus produziert viele Positionen (der volle Generator) und trägt seinen Haustyp.
        #expect(ausProjektGen.project.haustyp == .einfamilienhaus)
        #expect(ausProjektGen.massen.count > 10)
        #expect(ausProjektGen.phasen.count > 5)
    }

    // MARK: - Hofeinfahrt: kleine Vorlage, gleicher Ergebnis-Typ

    @Test func hofeinfahrtLiefertMassenPhasenUndKosten() {
        let r = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)

        #expect(r.project.projektName == "Hofeinfahrt pflastern")
        // Wenige, aber vorhandene Positionen — die vier Reiter haben Inhalt.
        #expect(r.massen.count == 6)
        #expect(r.materialien.count == 4)
        #expect(r.phasen.count == 4)
        #expect(r.baukosten.gesamtBaukosten > 0)

        // Skaliert mit der Fläche: die Pflasterfläche steht 1:1 als m² drin.
        let pflaster = r.massen.first { $0.bezeichnung.contains("Betonpflaster") }
        #expect(pflaster?.menge == 100)
        #expect(pflaster?.einheit == "m²")

        // Der Bauphasen-Plan (der Liebling) ist eine echte, kurze Kette.
        #expect(r.phasen.first?.startWoche == 0)
        #expect((r.phasen.map { $0.endeWoche }.max() ?? 0) >= 4)
    }

    @Test func groessereFlaecheGibtMehrPflaster() {
        let klein = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 50)
        let gross = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 200)
        #expect(gross.baukosten.gesamtBaukosten > klein.baukosten.gesamtBaukosten)
    }
}
