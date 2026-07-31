//
//  KennwertVergleichTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//
//  Nagelt die Zuordnung Kostengruppe -> Gewerke-Topf fest. Das ist die Stelle des
//  Kennwert-Vergleichs, an der man streiten kann — und genau deshalb die, die sich
//  unbemerkt verschiebt, wenn sie niemand festhaelt.
//
//  Was hier NICHT geprueft wird: ob der LVKalkulator richtig rechnet. Der Vergleich
//  ordnet zu und summiert, den Einheitspreis holt er sich woanders. Die Ist-Werte
//  werden darum gegen `LVKalkulator.effektiverEP` gehalten statt gegen feste Euro —
//  sonst faellt dieser Test um, sobald jemand an den Zuschlaegen dreht, und behauptet
//  dabei, die Zuordnung sei kaputt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

/// Serialisiert, weil mehrere Tests den Kennwert in den UserDefaults setzen. Parallel
/// wuerden sie sich gegenseitig den Wert unterm Stuhl wegziehen.
@Suite(.serialized)
struct KennwertVergleichTests {

    /// Eigener In-Memory-Stack, festgehalten (vgl. CLAUDE.md) — sonst gibt der
    /// Container die Objekte sofort wieder frei und die Attribute sind weg.
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    // MARK: - Zuordnung KG -> Topf

    @Test("Fenster und Tueren gehen NICHT als Rohbau durch")
    func fensterUndTuerenSindEigenerTopf() {
        // 334/344 stecken im LV unter 330/340, in der Schaetzung sind sie ein eigener
        // Topf. Faellt diese Sonderregel weg, wandern sie in den Rohbau und der
        // Rohbau-Vergleich stimmt auf beiden Seiten nicht mehr.
        #expect(KennwertVergleich.topf(fuerKostengruppe: "334") == "Fenster & Türen")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "344") == "Fenster & Türen")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "334.10") == "Fenster & Türen")

        // Die Nachbarn bleiben Rohbau — sonst waere die Regel zu gierig.
        #expect(KennwertVergleich.topf(fuerKostengruppe: "330") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "340") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "335") == "Rohbau")
    }

    @Test("Kostengruppe 300 verteilt sich auf Rohbau und Dach")
    func gruppe300() {
        #expect(KennwertVergleich.topf(fuerKostengruppe: "310") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "320") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "350") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "390") == "Rohbau")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "360") == "Dach")
    }

    @Test("Kostengruppe 400 trennt Sanitaer, Heizung und Elektro")
    func gruppe400() {
        #expect(KennwertVergleich.topf(fuerKostengruppe: "410") == "Sanitär")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "420") == "Heizung")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "430") == "Heizung")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "440") == "Elektro")
        #expect(KennwertVergleich.topf(fuerKostengruppe: "490") == "Elektro")
    }

    @Test("Was keine Bauleistung ist, faellt raus")
    func keineBauleistung() {
        // 100 Grundstueck, 200 Herrichten, 600 Ausstattung, 700 Baunebenkosten:
        // stehen nicht im LV eines Gewerks und duerfen den Vergleich nicht aufblaehen.
        #expect(KennwertVergleich.topf(fuerKostengruppe: "100") == nil)
        #expect(KennwertVergleich.topf(fuerKostengruppe: "200") == nil)
        #expect(KennwertVergleich.topf(fuerKostengruppe: "600") == nil)
        #expect(KennwertVergleich.topf(fuerKostengruppe: "700") == nil)
        #expect(KennwertVergleich.topf(fuerKostengruppe: "") == nil)
        #expect(KennwertVergleich.topf(fuerKostengruppe: "510") == "Außenanlagen")
    }

    // MARK: - Rechnung

    @Test("Ohne Planer-Konfiguration gibt es nichts zu vergleichen")
    @MainActor
    func ohneHouseProjectNil() {
        let event = Event(context: ctx)
        addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)

        // nil, nicht ein Ergebnis voller Nullen — die Oberflaeche soll "noch keine
        // Schaetzung" sagen koennen statt 0,00 EUR anzuzeigen.
        #expect(KennwertVergleich.berechne(fuer: event) == nil)
    }

    @Test("Verglichen wird nur, was das LV abdeckt")
    @MainActor
    func nurUeberschneidung() throws {
        try mitKennwert(mittel: 2500) {
            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)

            // LV deckt Rohbau und Dach ab — sonst nichts.
            addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)
            addPosition(event, posNr: "3.60.1", kg: "360", menge: 20, materialpreis: 30)

            let e = KennwertVergleich.berechne(fuer: event)
            let ergebnis = try #require(e)

            #expect(Set(ergebnis.zeilen.map(\.topf)) == ["Rohbau", "Dach"])

            // Sanitaer, Heizung, Maler & Co. kennt die Schaetzung, das LV nicht.
            // Sie muessen benannt sein — aber nicht mitgerechnet.
            #expect(ergebnis.nichtAbgedeckt.contains("Sanitär"))
            #expect(ergebnis.nichtAbgedeckt.contains("Heizung"))
            #expect(ergebnis.nichtAbgedeckt.contains("Maler"))
            #expect(!ergebnis.nichtAbgedeckt.contains("Rohbau"))
            #expect(!ergebnis.nichtAbgedeckt.contains("Dach"))
        }
    }

    @Test("Die Soll-Seite ist Wohnflaeche x Kennwert x Gewerke-Anteil")
    @MainActor
    func sollSeiteRechnetMitDemFirmenwert() throws {
        try mitKennwert(mittel: 2500) {
            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)
            addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)

            let ergebnis = try #require(KennwertVergleich.berechne(fuer: event))
            let rohbau = try #require(ergebnis.zeilen.first { $0.topf == "Rohbau" })

            // 100 m² x 2500 EUR = 250.000 gesamt, davon 32 % Rohbau (mit Keller).
            #expect(abs(rohbau.soll - 80_000) < 0.01)
            #expect(ergebnis.kennwertJeQm == 2500)
            #expect(ergebnis.wohnflaeche == 100)
        }
    }

    @Test("Der Kennwert kommt wirklich aus den Einstellungen")
    @MainActor
    func geaenderterKennwertSchlaegtDurch() throws {
        // Der Punkt der ganzen Umstellung: vorher standen 2500 hart im Code. Aendert
        // die Firma ihren Wert, muss die Schaetzung mitgehen.
        try mitKennwert(mittel: 3000) {
            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)
            addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)

            let ergebnis = try #require(KennwertVergleich.berechne(fuer: event))
            let rohbau = try #require(ergebnis.zeilen.first { $0.topf == "Rohbau" })

            #expect(ergebnis.kennwertJeQm == 3000)
            #expect(abs(rohbau.soll - 96_000) < 0.01)   // 100 x 3000 x 0,32
        }
    }

    @Test("Eine 0 in den Einstellungen faellt auf die Vorgabe zurueck")
    @MainActor
    func nullKennwertFaelltAufVorgabe() throws {
        // Ein Haus fuer 0 EUR/m² gibt es nicht. Ein versehentlich geleertes Feld darf
        // die Schaetzung nicht auf null ziehen — sonst waere jedes LV "ueber Plan".
        try mitKennwert(mittel: 0) {
            #expect(FirmenSettings.kennwertMittel == 2500)

            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)
            addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)

            let ergebnis = try #require(KennwertVergleich.berechne(fuer: event))
            #expect(ergebnis.sollGesamt > 0)
        }
    }

    @Test("Positionen desselben Topfs werden addiert")
    @MainActor
    func istSeiteSummiertJeTopf() throws {
        try mitKennwert(mittel: 2500) {
            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)

            let a = addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)
            let b = addPosition(event, posNr: "3.20.1", kg: "320", menge: 5,  materialpreis: 40)
            addPosition(event, posNr: "3.60.1", kg: "360", menge: 20, materialpreis: 30)

            let ergebnis = try #require(KennwertVergleich.berechne(fuer: event))
            let rohbau = try #require(ergebnis.zeilen.first { $0.topf == "Rohbau" })

            // Gegen den Kalkulator gehalten, nicht gegen feste Euro: geprueft wird das
            // Addieren, nicht das Preisrechnen.
            let erwartet = LVKalkulator.effektiverEP(for: a) * a.menge
                         + LVKalkulator.effektiverEP(for: b) * b.menge
            #expect(abs(rohbau.ist - erwartet) < 0.01)
            #expect(erwartet > 0)   // sonst prueft der Vergleich oben nur 0 == 0
        }
    }

    @Test("Ein Beleg unter einem Deckel zaehlt nicht doppelt")
    @MainActor
    func belegeUnterDeckelZaehlenNicht() throws {
        // REB-23.003: die Belege stecken IM Deckel. Zaehlt der Vergleich sie daneben
        // nochmal mit, ist das Ist doppelt so hoch und das LV sieht grundlos teuer aus.
        try mitKennwert(mittel: 2500) {
            let event = Event(context: ctx)
            setzeProjekt(event, wohnflaeche: 100, keller: true)

            let deckel = addPosition(event, posNr: "3.30.1", kg: "330", menge: 10, materialpreis: 50)
            let beleg  = addPosition(event, posNr: "3.30.1.1", kg: "330", menge: 4, materialpreis: 25)
            beleg.deckel = deckel

            let ergebnis = try #require(KennwertVergleich.berechne(fuer: event))
            let rohbau = try #require(ergebnis.zeilen.first { $0.topf == "Rohbau" })

            let nurDeckel = LVKalkulator.effektiverEP(for: deckel) * deckel.menge
            #expect(abs(rohbau.ist - nurDeckel) < 0.01)
        }
    }

    @Test("Abweichung ohne Soll-Wert gibt kein Prozent aus")
    func prozentBrauchtEinenSollWert() throws {
        // Division durch 0 waere "unendlich Prozent ueber Plan" — die Ansicht soll die
        // Zeile dann lieber ohne Prozentangabe zeigen.
        let z = KennwertVergleich.Zeile(topf: "Rohbau", soll: 0, ist: 5000)
        #expect(z.abweichungProzent == nil)
        #expect(z.abweichung == 5000)

        let z2 = KennwertVergleich.Zeile(topf: "Rohbau", soll: 10_000, ist: 8_000)
        #expect(z2.abweichung == -2000)
        #expect(abs(try #require(z2.abweichungProzent) - (-0.2)) < 0.0001)
    }

    // MARK: - Aufbau

    /// Setzt einen Kennwert, fuehrt den Test aus und raeumt hinterher auf — sonst
    /// stehen die Werte in den UserDefaults des Simulators und faerben den naechsten
    /// Lauf ein.
    @MainActor
    private func mitKennwert(mittel: Double, _ body: () throws -> Void) rethrows {
        let key = FirmenSettings.Keys.kennwertMittel
        let alt = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(mittel, forKey: key)
        defer {
            if let alt {
                UserDefaults.standard.set(alt, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        try body()
    }

    @MainActor
    private func setzeProjekt(_ event: Event, wohnflaeche: Double, keller: Bool) {
        var projekt = HouseProject()
        projekt.wohnflaeche = wohnflaeche
        projekt.kellerGeplant = keller
        projekt.ausstattung = .mittel
        // Aus: sonst schlagen Waermepumpe & Co. Pauschalen auf einzelne Toepfe und die
        // Soll-Werte oben stimmen nicht mehr glatt.
        projekt.waermepumpe = false
        projekt.solaranlage = false
        projekt.smartHome = false
        projekt.garage = false

        var extras = EventExtrasPayload.laden(aus: event)
        extras.houseProject = projekt
        extras.speichern(in: event)
    }

    /// Eine Position mit genau einem Materialposten — reicht, damit
    /// `effektiverEP` einen Preis liefert (ohne Kalkulation gibt er 0 zurueck).
    @discardableResult
    @MainActor
    private func addPosition(_ event: Event,
                             posNr: String,
                             kg: String,
                             menge: Double,
                             materialpreis: Double) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = posNr
        p.bezeichnung = "Position \(posNr)"
        p.menge = menge
        p.einheit = "m²"
        p.kostenGruppeNummer = kg
        p.event = event
        // Eigene Saetze statt Firmenwerte — sonst haengt der Test an den Zuschlaegen
        // in den UserDefaults (vgl. ElementKalkulationTests).
        p.zuschlagEigen = true
        p.bgkProzent = 0
        p.wagnisGewinnProzent = 0

        let m = PositionMaterial(context: ctx)
        m.id = UUID()
        m.materialName = "Material \(posNr)"
        m.einzelpreis = materialpreis
        m.mengeProEinheit = 1
        m.verschnittProzent = 0
        m.position = p

        return p
    }
}
