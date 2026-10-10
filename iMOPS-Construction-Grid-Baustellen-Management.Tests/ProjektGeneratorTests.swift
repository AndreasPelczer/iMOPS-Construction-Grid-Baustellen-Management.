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
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ProjektGeneratorTests {

    // Festgehalten (nicht inline): sonst gibt der In-Memory-Stack den Container sofort
    // wieder frei und die Objekte verlieren ihre Attribute (siehe CLAUDE.md).
    private let controller = PersistenceController(inMemory: true)

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

    /// Die Pflasterfläche steht als `wohnflaeche` im Ergebnis — sonst zeigt der
    /// Konfigurator „0 m²" und rechnet EUR/m² = Kosten ÷ 0 (NaN).
    @Test func hofeinfahrtSetztDieFlaeche() {
        let r = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)
        #expect(r.project.wohnflaeche == 100)
        // Und damit ist EUR/m² eine echte Zahl statt NaN.
        #expect(r.project.wohnflaeche > 0)
        let proQm = r.gesamtkosten / r.project.wohnflaeche
        #expect(proQm.isFinite && proQm > 0)
    }

    /// „Als Baustelle anlegen" pinnt jetzt auch das Tiefbau-Material an die Baustelle —
    /// vorher kannte `bekannteCodeMap` nur Hochbau, die Materialliste blieb leer.
    @Test @MainActor func konfiguratorHofeinfahrtPinntMaterial() throws {
        let ctx = controller.container.viewContext
        let r = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)
        let event = HouseProjectGenerator.createEvent(from: r, into: ctx)

        let extras = EventExtrasPayload.laden(aus: event)
        #expect(!extras.pinnedLexikonCodes.isEmpty)
        for code in ["SCH-032", "PFL-VBS", "SPL-208", "RND-TB"] {
            #expect(extras.pinnedLexikonCodes.contains(code))
        }
    }
}

// MARK: - Befund 10.10.2026: gespeicherte Planung mit dem Rechner IHRES Typs neu rechnen

struct GrundplanungNachTypTests {
    @Test func hofeinfahrtBleibtHofeinfahrt() {
        let erzeugt = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)
        #expect(erzeugt.project.projektTyp == "hofeinfahrt")
        let neu = ProjektGenerator.neuBerechnen(erzeugt.project)
        #expect(abs(neu.gesamtkosten - erzeugt.gesamtkosten) < 0.01)
        #expect(neu.gesamtkosten < 50_000)   // keine 300.000 € mehr für 100 m² Pflaster
    }

    @Test func altbestandOhneTypWirdAmNamenErkannt() throws {
        var alt = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100).project
        alt.projektTyp = nil   // so liegt Müller vom 10.10. gespeichert
        #expect(ProjektGenerator.typ(von: alt) == .hofeinfahrt)
        let daten = try JSONEncoder().encode(alt)
        let gelesen = try JSONDecoder().decode(HouseProject.self, from: daten)
        #expect(ProjektGenerator.neuBerechnen(gelesen).gesamtkosten < 50_000)
    }

    @Test func hausRechnetWieBisher() {
        let haus = HouseProject()
        #expect(abs(ProjektGenerator.neuBerechnen(haus).gesamtkosten - HouseProjectGenerator.generate(from: haus).gesamtkosten) < 0.01)
    }
}
