//
//  RaphaelStammdatenSeederTests.swift
//  Der Beweis: rechnet der Mops wie Raphaels Software?
//
//  ⚠️ Die Werte hier sind reale Preise eines Betriebs — vertraulich behandeln.
//
//  ⚠️ Diese Tests schreiben in `UserDefaults` (die Firmen-Zuschläge sind dort
//     abgelegt, nicht in Core Data). Das ist globaler Zustand, der alle anderen
//     Tests beeinflussen würde. Jeder Test stellt ihn deshalb über `defer`
//     wieder her — sonst rechnet eine fremde Suite plötzlich mit Raphaels
//     Zuschlägen und fällt scheinbar grundlos durch.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct RaphaelStammdatenSeederTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Sichert die Zuschlags-Einstellungen und gibt eine Funktion zum
    /// Zurücksetzen zurück. `nil` heißt: der Schlüssel war vorher nicht gesetzt.
    private func sichereEinstellungen() -> () -> Void {
        let d = UserDefaults.standard
        let keys = [FirmenSettings.Keys.zuschlagJeKostenart,
                    FirmenSettings.Keys.zuschlagLohn,
                    FirmenSettings.Keys.zuschlagMaterial,
                    FirmenSettings.Keys.zuschlagGeraet]
        let vorher = keys.map { ($0, d.object(forKey: $0)) }
        return {
            for (key, wert) in vorher {
                if let wert { d.set(wert, forKey: key) } else { d.removeObject(forKey: key) }
            }
        }
    }

    @MainActor
    private func lohnsatz(_ name: String) throws -> Lohnsatz {
        let r: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        r.predicate = NSPredicate(format: "qualifikation == %@", name)
        return try #require(try ctx.fetch(r).first)
    }

    // MARK: - Der Beweis: Li × Zuschlag = Kalkpreis

    /// **Lohn.** Der Zuschlag steckt im Stammsatz selbst:
    /// `berechnungBruttoEK = stundenlohn × zuschlagFaktor`.
    ///
    /// ⚠️ **Toleranz 1,5 Cent, nicht ein halber.** Raphaels Zahlen gehen mit
    /// Faktor 2,75 nicht auf den Cent auf:
    ///
    ///     27,64 × 2,75 = 76,01    (angezeigt: 76,00)   +1 ct
    ///     26,91 × 2,75 = 74,0025  (angezeigt: 74,00)
    ///     16,36 × 2,75 = 44,99    (angezeigt: 45,00)   −1 ct
    ///
    /// Die wahren Faktoren lägen bei 2,7496 / 2,7499 / 2,7506 — die Li-Preise
    /// sind also gerundet angezeigt. Ein einheitlicher Faktor 2,75 ist richtiger
    /// als drei krumme, die eine Genauigkeit vortäuschen, die die Quelle nicht
    /// hergibt. **Für centgenauen Abgleich mit Raphaels Software muss geklärt
    /// werden, mit wie vielen Nachkommastellen sie rechnet.**
    @Test @MainActor func lohnRechnetAufRaphaelsKalkpreis() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        let cent = 0.015
        #expect(abs(try lohnsatz("Facharbeiter (Raphael)").berechnungBruttoEK - 74.00) < cent)
        #expect(abs(try lohnsatz("Spezialfacharbeiter").berechnungBruttoEK   - 74.00) < cent)
        #expect(abs(try lohnsatz("Meisterstunden").berechnungBruttoEK        - 76.00) < cent)
        #expect(abs(try lohnsatz("Polierstunden").berechnungBruttoEK         - 76.00) < cent)
        #expect(abs(try lohnsatz("Vorarbeiterstunden").berechnungBruttoEK    - 76.00) < cent)
        #expect(abs(try lohnsatz("Lehrling 3. Lehrjahr").berechnungBruttoEK  - 45.00) < cent)

        // Und der rohe Li-Preis steht auch wirklich als Li drin, nicht der Kalkpreis.
        #expect(abs(try lohnsatz("Facharbeiter (Raphael)").stundenlohn - 26.91) < 0.005)
    }

    /// **Material.** Der Stammsatz trägt den EK; die 15 % kommen erst im
    /// `LVKalkulator` über die Firmen-Zuschläge dazu. Der Test baut eine echte
    /// Position und lässt den Mops rechnen — nicht die Formel nachrechnen.
    @Test @MainActor func materialRechnetAufRaphaelsKalkpreis() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
        r.predicate = NSPredicate(format: "name == %@", "Schotter 0/32")
        let stamm = try #require(try ctx.fetch(r).first)
        #expect(abs(stamm.preisProEinheit - 10.00) < 0.005, "Stammsatz muss der Li-Preis sein")

        // Eine Position mit genau einer Tonne dieses Materials.
        let pos = LVPosition(context: ctx)
        pos.menge = 1
        pos.einheit = "to"
        let pm = PositionMaterial(context: ctx)
        pm.id = UUID()
        pm.materialName = stamm.name
        pm.mengeProEinheit = 1
        pm.einheit = stamm.einheit
        pm.einzelpreis = stamm.preisProEinheit    // wie MaterialHinzufuegenView es übernimmt
        pm.verschnittProzent = 0
        pm.position = pos

        let k = LVKalkulator.kalkuliere(position: pos)
        #expect(abs(k.materialKosten - 10.00) < 0.005, "EK: \(k.materialKosten)")
        #expect(abs(k.einheitspreisVK - 11.50) < 0.005,
                "Kalkpreis: \(k.einheitspreisVK) — erwartet 11,50")
    }

    /// **Gerät.** Der Verrechnungssatz steht als `anschaffungsKosten` bei
    /// Nutzungsdauer 1 — das Modell hat kein Feld für einen Stundensatz. Die
    /// 10 % kommen über die Firmen-Zuschläge dazu.
    @Test @MainActor func geraetRechnetAufRaphaelsKalkpreis() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<Geraet> = Geraet.fetchRequest()
        r.predicate = NSPredicate(format: "name == %@", "Bagger 9to")
        let stamm = try #require(try ctx.fetch(r).first)
        #expect(abs(stamm.kostenProStunde - 45.60) < 0.005, "Li je Stunde")

        let pos = LVPosition(context: ctx)
        pos.menge = 1
        pos.einheit = "h"
        let pg = PositionGeraet(context: ctx)
        pg.id = UUID()
        pg.geraetName = stamm.name
        pg.stunden = 1
        pg.kostenProStunde = stamm.kostenProStunde
        pg.position = pos

        let k = LVKalkulator.kalkuliere(position: pos)
        #expect(abs(k.geraeteKosten - 45.60) < 0.005)
        #expect(abs(k.einheitspreisVK - 50.16) < 0.005,
                "Kalkpreis: \(k.einheitspreisVK) — erwartet 50,16")
    }

    // MARK: - Die Zuschläge

    /// Ohne `zuschlagJeKostenart` greifen die drei Sätze **gar nicht** — dann
    /// rechnet der `LVKalkulator` Wagnis & Gewinn auf die Summe. Der Schalter
    /// ist damit Voraussetzung für die ganze Kette.
    @Test @MainActor func zuschlaegeStehenAufRaphaelsWerten() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        #expect(FirmenSettings.zuschlagJeKostenart == true)
        #expect(abs(FirmenSettings.zuschlagMaterial - 0.15) < 0.0001)
        #expect(abs(FirmenSettings.zuschlagGeraet   - 0.10) < 0.0001)
    }

    /// **Der Befund, der den Auftrag korrigiert.** Die 175 % stecken bereits im
    /// `Lohnsatz.zuschlagFaktor`. Stünde `zuschlagLohn` zusätzlich auf 1,75,
    /// rechnete der Mops 74,00 × 2,75 = **203,50 €/h**.
    ///
    /// Der Test hält beides fest: dass der Firmenzuschlag auf 0 steht, und was
    /// passieren würde, wenn er es nicht täte.
    @Test @MainActor func lohnZuschlagWirdNichtDoppeltAufgeschlagen() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        #expect(abs(FirmenSettings.zuschlagLohn) < 0.0001,
                "zuschlagLohn muss 0 sein — die 175 % stecken im Lohnsatz")

        let pos = LVPosition(context: ctx)
        pos.menge = 1
        pos.einheit = "h"
        let pl = PositionLohn(context: ctx)
        pl.id = UUID()
        pl.qualifikation = "Facharbeiter (Raphael)"
        pl.stunden = 1
        pl.stundenBruttoEK = try lohnsatz("Facharbeiter (Raphael)").berechnungBruttoEK
        pl.position = pos

        let k = LVKalkulator.kalkuliere(position: pos)
        #expect(abs(k.einheitspreisVK - 74.00) < 0.005,
                "Kalkpreis Lohn: \(k.einheitspreisVK) — erwartet 74,00")

        // Gegenprobe: mit 1,75 als Firmenzuschlag käme das Doppelte heraus.
        UserDefaults.standard.set(1.75, forKey: FirmenSettings.Keys.zuschlagLohn)
        let falsch = LVKalkulator.kalkuliere(position: pos)
        #expect(abs(falsch.einheitspreisVK - 203.50) < 0.01,
                "Gegenprobe: \(falsch.einheitspreisVK)")
    }

    // MARK: - Verträglichkeit

    /// Die Demo-Stammdaten des `StammdatenSeeder` bleiben unberührt. Beide
    /// Seeder dürfen nebeneinander laufen, ohne sich zu überschreiben.
    @Test @MainActor func demoStammdatenBleibenUnberuehrt() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        StammdatenSeeder.seedIfNeeded(context: ctx)
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        // Der alte „Polier" (Demo, 32,00 × 1,75) steht neben „Polierstunden".
        let alt = try lohnsatz("Polier")
        #expect(abs(alt.stundenlohn - 32.00) < 0.005)
        #expect(abs(try lohnsatz("Polierstunden").stundenlohn - 27.64) < 0.005)
    }

    @Test @MainActor func zweiterLaufLegtNichtsDoppeltAn() throws {
        let zurueck = sichereEinstellungen(); defer { zurueck() }
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)
        RaphaelStammdatenSeeder.seedIfNeeded(context: ctx)

        func anzahl<T: NSManagedObject>(_ typ: T.Type, _ feld: String, _ wert: String) throws -> Int {
            let r = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: typ))
            r.predicate = NSPredicate(format: "%K == %@", feld, wert)
            return try ctx.count(for: r)
        }

        #expect(try anzahl(Lohnsatz.self, "qualifikation", "Facharbeiter (Raphael)") == 1)
        #expect(try anzahl(KalkMaterial.self, "name", "Schotter 0/32") == 1)
        #expect(try anzahl(Geraet.self, "name", "Bagger 9to") == 1)
    }
}
