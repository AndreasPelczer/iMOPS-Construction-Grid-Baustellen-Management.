//
//  ElementKalkulationTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//
//  B-Element: ein Deckel, der seine Bausteine zu EINEM Einheitspreis zusammenrechnet.
//  Gerechnet wird das Pflaster-Beispiel vom Zettel: acht Arbeitsschritte, am Ende
//  steht ein Preis je m².
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ElementKalkulationTests {

    /// Eigener In-Memory-Stack je Test, festgehalten (vgl. CLAUDE.md) — sonst gibt der
    /// Container die Objekte sofort wieder frei und die Attribute sind weg.
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    // MARK: - Aufbau

    /// Das B-Element: 100 m² Pflasterfläche, Zuschlag 12 % BGK + 8 % W&G.
    @MainActor
    private func makeElement() -> LVPosition {
        let el = LVPosition(context: ctx)
        el.posNr = "534.000"
        el.bezeichnung = "Pflasterfläche"
        el.menge = 100
        el.einheit = "m²"
        el.bgkProzent = 0.12
        el.wagnisGewinnProzent = 0.08
        el.deckelTyp = .element
        return el
    }

    @MainActor
    private func makeBaustein(_ element: LVPosition,
                              posNr: String,
                              bezeichnung: String,
                              einheit: String,
                              jeElementEinheit: Double) -> LVPosition {
        let b = LVPosition(context: ctx)
        b.posNr = posNr
        b.bezeichnung = bezeichnung
        b.einheit = einheit
        b.mengeJeDeckelEinheit = jeElementEinheit
        // Bausteine tragen eigene Zuschlagsätze — die müssen ignoriert werden,
        // sonst wird doppelt aufgeschlagen. Bewusst ungleich null gesetzt.
        b.bgkProzent = 0.12
        b.wagnisGewinnProzent = 0.08
        b.deckel = element
        return b
    }

    @MainActor
    private func addMaterial(_ pos: LVPosition, preis: Double, jeEinheit: Double = 1.0) {
        let m = PositionMaterial(context: ctx)
        m.id = UUID()
        m.materialName = "Material \(pos.posNr ?? "")"
        m.einzelpreis = preis
        m.mengeProEinheit = jeEinheit
        m.verschnittProzent = 0
        m.position = pos
    }

    @MainActor
    private func addLohn(_ pos: LVPosition, satz: Double, stunden: Double) {
        let l = PositionLohn(context: ctx)
        l.id = UUID()
        l.qualifikation = "Facharbeiter"
        l.stundenBruttoEK = satz
        l.stunden = stunden
        l.position = pos
    }

    @MainActor
    private func addGeraet(_ pos: LVPosition, satz: Double, stunden: Double) {
        let g = PositionGeraet(context: ctx)
        g.id = UUID()
        g.geraetName = "Rüttelplatte"
        g.kostenProStunde = satz
        g.stunden = stunden
        g.position = pos
    }

    /// Das vollständige Rezept — vier Bausteine in DREI verschiedenen Einheiten:
    ///
    ///   Frostschutz     50 €/m³ × 0,35 m³/m²  = 17,50 €/m²
    ///   Pflastersteine  25 €/m² × 1,00 m²/m²  = 25,00 €/m²
    ///   Verlegen        55 €/h  × 0,50 h/m²   = 27,50 €/m²
    ///   Abrütteln       25 €/h  × 0,10 h/m²   =  2,50 €/m²
    ///                                          ─────────────
    ///                             Selbstkosten = 72,50 €/m²
    ///                             + 20 % Zuschlag = 87,00 €/m²
    @MainActor
    private func makeVollesRezept() -> LVPosition {
        let el = makeElement()

        let frostschutz = makeBaustein(el, posNr: "534.002", bezeichnung: "Frostschutz",
                                       einheit: "m³", jeElementEinheit: 0.35)
        addMaterial(frostschutz, preis: 50)

        let steine = makeBaustein(el, posNr: "534.004", bezeichnung: "Pflastersteine",
                                  einheit: "m²", jeElementEinheit: 1.0)
        addMaterial(steine, preis: 25)

        let verlegen = makeBaustein(el, posNr: "534.005", bezeichnung: "Pflaster verlegen",
                                    einheit: "m²", jeElementEinheit: 1.0)
        addLohn(verlegen, satz: 55, stunden: 0.5)

        let abruetteln = makeBaustein(el, posNr: "534.007", bezeichnung: "Abrütteln",
                                      einheit: "h", jeElementEinheit: 0.1)
        addGeraet(abruetteln, satz: 25, stunden: 1.0)

        return el
    }

    // MARK: - Tests

    @Test @MainActor
    func elementRechnetEinheitspreisAusBausteinen() throws {
        let el = makeVollesRezept()
        let k = LVKalkulator.kalkuliereElement(el)

        // Selbstkosten je m² — die Bausteine rechnen in m³, m² und h, das Ergebnis in m².
        #expect(abs(k.einheitspreisEK - 72.50) < 0.001)
        // Zuschlag EINMAL oben: 72,50 × 1,20
        #expect(abs(k.einheitspreisVK - 87.00) < 0.001)
        #expect(abs(k.gesamtpreis - 8_700.00) < 0.01)
        #expect(abs(k.menge - 100) < 0.001)
    }

    @Test @MainActor
    func anteileWerdenAufgeschluesselt() throws {
        let el = makeVollesRezept()
        let k = LVKalkulator.kalkuliereElement(el)

        #expect(abs(k.materialKosten - 42.50) < 0.001)   // 17,50 + 25,00
        #expect(abs(k.lohnKosten - 27.50) < 0.001)
        #expect(abs(k.geraeteKosten - 2.50) < 0.001)
    }

    @Test @MainActor
    func rezeptSkaliertMitDerBezugsmenge() throws {
        let el = makeVollesRezept()
        let epVorher = LVKalkulator.kalkuliereElement(el).einheitspreisVK

        el.menge = 250   // andere Baustelle, dieselbe Rezeptur

        let k = LVKalkulator.kalkuliereElement(el)
        #expect(abs(k.einheitspreisVK - epVorher) < 0.001)   // Preis je m² bleibt
        #expect(abs(k.gesamtpreis - 21_750.00) < 0.01)       // Gesamt skaliert mit
    }

    @Test @MainActor
    func bausteinTraegtKeinenZuschlagUndRechnetMitRezeptMenge() throws {
        let el = makeElement()
        let frostschutz = makeBaustein(el, posNr: "534.002", bezeichnung: "Frostschutz",
                                       einheit: "m³", jeElementEinheit: 0.35)
        addMaterial(frostschutz, preis: 50)

        #expect(frostschutz.istElementBaustein)
        // 0,35 m³/m² × 100 m² = 35 m³
        #expect(abs(frostschutz.effektiveMenge - 35.0) < 0.001)

        let k = LVKalkulator.kalkuliere(position: frostschutz)
        #expect(abs(k.einheitspreisEK - 50.0) < 0.001)
        #expect(abs(k.zuschlagBGK - 0) < 0.001)    // Zuschlag traegt das Element
        #expect(abs(k.zuschlagWG - 0) < 0.001)
        #expect(abs(k.einheitspreisVK - 50.0) < 0.001)
        #expect(abs(k.gesamtpreis - 1_750.0) < 0.01)   // 50 × 35
    }

    @Test @MainActor
    func effektiverEPLiefertDenElementPreis() throws {
        let el = makeVollesRezept()
        #expect(abs(LVKalkulator.effektiverEP(for: el) - 87.00) < 0.001)
    }

    // MARK: - Kein Rueckschritt fuer Bestehendes

    @Test @MainActor
    func mengentraegerDeckelVerhaeltSichUnveraendert() throws {
        // So kommen Excel-/Bestelllisten-Importe herein: deckelArt bleibt nil.
        let deckel = LVPosition(context: ctx)
        deckel.posNr = "06.01"
        deckel.bezeichnung = "Außenwand 24 cm"
        deckel.menge = 80
        deckel.einheit = "m²"
        deckel.bgkProzent = 0.12
        deckel.wagnisGewinnProzent = 0.08
        addMaterial(deckel, preis: 30)

        let beleg = LVPosition(context: ctx)
        beleg.posNr = "06.01.1"
        beleg.bezeichnung = "Wand EG Nord"
        beleg.menge = 30
        beleg.deckel = deckel

        #expect(deckel.istDeckel)
        #expect(!deckel.istElement)                  // ohne Markierung kein Element
        #expect(deckel.deckelTyp == .mengentraeger)  // Vorgabe bei nil
        #expect(!beleg.istElementBaustein)
        #expect(abs(beleg.effektiveMenge - 30.0) < 0.001)   // Beleg behaelt seine Menge

        // Der Deckel rechnet wie bisher aus SEINER Kalkulation, nicht aus den Belegen:
        // 30 €/m² + 20 % = 36 €/m².
        let k = LVKalkulator.kalkuliere(position: deckel)
        #expect(abs(k.einheitspreisVK - 36.0) < 0.001)
        #expect(abs(k.gesamtpreis - 2_880.0) < 0.01)
    }

    @Test @MainActor
    func eigenstaendigePositionUnveraendert() throws {
        let pos = LVPosition(context: ctx)
        pos.posNr = "3.30.1"
        pos.menge = 10
        pos.einheit = "m²"
        pos.bgkProzent = 0.12
        pos.wagnisGewinnProzent = 0.08
        addMaterial(pos, preis: 100)

        #expect(abs(pos.effektiveMenge - 10.0) < 0.001)
        let k = LVKalkulator.kalkuliere(position: pos)
        #expect(abs(k.einheitspreisVK - 120.0) < 0.001)   // Zuschlag greift weiterhin
        #expect(abs(k.gesamtpreis - 1_200.0) < 0.01)
    }

    /// Regressions-Wache. Der erste Screenshot zeigte 2.880 EUR statt 11.580 EUR:
    /// das Element fiel aus der Angebotssumme, weil die Summen-Logik nur
    /// `hatKalkulation` kannte und ein Element selbst keine Kalkulation hat.
    @Test @MainActor
    func gesamtsummeEnthaeltDasElement() throws {
        let element = makeVollesRezept()                  // 87,00 x 100 m² = 8.700
        let wand = LVPosition(context: ctx)               // 36,00 x  80 m² = 2.880
        wand.posNr = "331.001"
        wand.menge = 80
        wand.einheit = "m²"
        wand.bgkProzent = 0.12
        wand.wagnisGewinnProzent = 0.08
        addMaterial(wand, preis: 30)

        let beleg = LVPosition(context: ctx)              // zaehlt nicht
        beleg.posNr = "331.001.1"
        beleg.menge = 30
        beleg.deckel = wand

        let alle = [element, wand, beleg] + element.unterPositionenArray
        #expect(abs(LVKalkulator.gesamtKalkulation(positionen: alle) - 11_580.00) < 0.01)
    }

    // MARK: - Zuschlag je Kostenart

    /// Der Schalter allein darf KEINE Zahl bewegen: 20 % je Kostenart ist dieselbe
    /// Summe wie 12 % BGK + 8 % W&G auf alles. Erst wer an einem Regler dreht,
    /// aendert den Preis.
    @Test @MainActor
    func umschaltenAlleinAendertNichts() throws {
        let el = makeVollesRezept()
        let vorher = LVKalkulator.kalkuliereElement(el).einheitspreisVK

        el.zuschlagJeKostenart = true      // Vorgaben stehen auf je 0,20

        #expect(abs(LVKalkulator.kalkuliereElement(el).einheitspreisVK - vorher) < 0.001)
        #expect(abs(vorher - 87.00) < 0.001)
    }

    /// Das Verfahren aus dem BauSU-Bild: Lohn traegt den Loewenanteil.
    /// Selbstkosten je m²: Material 42,50 · Lohn 27,50 · Geraet 2,50
    ///   Lohn     27,50 x 1,75 = 48,125
    ///   Material 42,50 x 0,15 =  6,375
    ///   Geraet    2,50 x 0,10 =  0,250
    ///   72,50 + 54,75 = 127,25 EUR/m²
    @Test @MainActor
    func lohnTraegtDenLoewenanteil() throws {
        let el = makeVollesRezept()
        el.zuschlagJeKostenart = true
        el.zuschlagLohnProzent = 1.75      // x2,75
        el.zuschlagMaterialProzent = 0.15  // x1,15
        el.zuschlagGeraetProzent = 0.10    // x1,10

        let k = LVKalkulator.kalkuliereElement(el)
        #expect(abs(k.zuschlagLohn - 48.125) < 0.001)
        #expect(abs(k.zuschlagMaterial - 6.375) < 0.001)
        #expect(abs(k.zuschlagGeraet - 0.250) < 0.001)
        // W&G und BGK werden in diesem Verfahren NICHT zusaetzlich gerechnet.
        #expect(abs(k.zuschlagWG - 0) < 0.001)
        #expect(abs(k.zuschlagBGK - 0) < 0.001)
        #expect(abs(k.einheitspreisVK - 127.25) < 0.001)
        #expect(abs(k.gesamtpreis - 12_725.00) < 0.01)
    }

    @Test @MainActor
    func bausteinTraegtAuchJeKostenartKeinenZuschlag() throws {
        let el = makeElement()
        el.zuschlagJeKostenart = true
        el.zuschlagLohnProzent = 1.75

        let verlegen = makeBaustein(el, posNr: "534.005", bezeichnung: "Pflaster verlegen",
                                    einheit: "m²", jeElementEinheit: 1.0)
        verlegen.zuschlagJeKostenart = true      // eigener Schalter — muss ignoriert werden
        verlegen.zuschlagLohnProzent = 1.75
        addLohn(verlegen, satz: 55, stunden: 0.5)

        let k = LVKalkulator.kalkuliere(position: verlegen)
        #expect(abs(k.zuschlagLohn - 0) < 0.001)
        #expect(abs(k.einheitspreisVK - 27.50) < 0.001)   // reine Selbstkosten
    }

    // MARK: - Lohnstunden

    @Test @MainActor
    func elementSummiertLohnstundenUeberDasRezept() throws {
        let el = makeVollesRezept()          // einziger Lohn: 0,5 Std je m², Faktor 1,0
        let k = LVKalkulator.kalkuliereElement(el)

        #expect(abs(k.stundenJeEinheit - 0.5) < 0.001)
        #expect(abs(k.stundenGesamt - 50.0) < 0.001)      // 0,5 x 100 m²
    }

    @Test @MainActor
    func stundenSkalierenMitDemRezeptMass() throws {
        let el = makeElement()
        // Abruetteln rechnet in Stunden: 1,0 Std je Baustein-Einheit, 0,1 je m².
        let abruetteln = makeBaustein(el, posNr: "534.007", bezeichnung: "Abrütteln",
                                      einheit: "h", jeElementEinheit: 0.1)
        addLohn(abruetteln, satz: 26.55, stunden: 1.0)

        let k = LVKalkulator.kalkuliereElement(el)
        #expect(abs(k.stundenJeEinheit - 0.1) < 0.001)    // 1,0 x 0,1
        #expect(abs(k.stundenGesamt - 10.0) < 0.001)      // x 100 m²
    }

    @Test @MainActor
    func gesamtstundenUeberDasGanzeLV() throws {
        let element = makeVollesRezept()                  // 50 Std
        let wand = LVPosition(context: ctx)               // 0,8 Std/m² x 80 = 64 Std
        wand.posNr = "331.001"
        wand.menge = 80
        wand.einheit = "m²"
        addLohn(wand, satz: 50, stunden: 0.8)

        let beleg = LVPosition(context: ctx)              // zaehlt nicht
        beleg.posNr = "331.001.1"
        beleg.menge = 30
        beleg.deckel = wand
        addLohn(beleg, satz: 50, stunden: 2.0)

        let alle = [element, wand, beleg] + element.unterPositionenArray
        #expect(abs(LVKalkulator.gesamtStunden(positionen: alle) - 114.0) < 0.001)
    }

    @Test @MainActor
    func leerMarkiertesElementRechnetNichts() throws {
        let el = LVPosition(context: ctx)
        el.menge = 100
        el.deckelTyp = .element      // markiert, aber ohne Bausteine

        #expect(!el.istElement)      // ohne Kinder kein Element
        #expect(abs(LVKalkulator.kalkuliereElement(el).einheitspreisVK - 0) < 0.001)
    }
}
