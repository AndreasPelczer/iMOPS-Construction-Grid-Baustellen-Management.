//
//  MopsFassTests.swift
//  „Mops fass": der AutoKalkulationsService läuft über ein importiertes LV, matcht jede
//  Position gegen den Leistungskatalog und meldet ehrlich, was fehlt.
//
//  Kern: GRÜN nur bei echtem Preis aus einem Rezept, GELB wenn ein Wert fehlt
//  (Aufwandswert/Material), ROT wenn es gar kein Rezept gibt. Keine erfundene Zahl.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MopsFassTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func position(_ bezeichnung: String, _ einheit: String, menge: Double = 10) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = bezeichnung; pos.einheit = einheit; pos.menge = menge
        return pos
    }

    @Test @MainActor func grueneWennRezeptMitAufwandwert() throws {
        // Vollständiges Rezept (Maurer/Helfer-Stunden) → LVKalkulator liefert einen Preis.
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        let e = AutoKalkulationsService.bewerte(position("Betonwände herstellen", "m²"), in: ctx)
        #expect(e.status == .gruen)
        #expect(e.einheitspreisVK > 0)
    }

    @Test @MainActor func roteWennKeinRezept() throws {
        let e = AutoKalkulationsService.bewerte(position("Dachbegrünung extensiv", "m²"), in: ctx)
        #expect(e.status == .rot)
        #expect(e.einheitspreisVK == 0)
        #expect(e.meldungen.contains { $0.contains("Kein gelerntes Rezept") })
    }

    @Test @MainActor func gelbeWennAufwandwertFehlt() throws {
        // Rezept da, aber ohne Aufwandswert (wie die Tiefbau-Rezepte: Lohn 0 bewusst).
        LeistungskatalogService.merke(leistung: "Oberboden abtragen", einheit: "m³",
                                      maurer: 0, helfer: 0, in: ctx)
        let e = AutoKalkulationsService.bewerte(position("Oberboden abtragen", "m³"), in: ctx)
        #expect(e.status == .gelb)
        #expect(e.meldungen.contains { $0.contains("Aufwandswert") })
    }

    @Test @MainActor func bilanzZaehltAmpelUndExportGate() throws {
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        LeistungskatalogService.merke(leistung: "Oberboden abtragen", einheit: "m³",
                                      maurer: 0, helfer: 0, in: ctx)
        let positionen = [
            position("Betonwände herstellen", "m²"),   // grün
            position("Oberboden abtragen", "m³"),       // gelb
            position("Dachbegrünung extensiv", "m²"),   // rot
        ]
        let ergebnisse = AutoKalkulationsService.fass(positionen: positionen, in: ctx)
        let b = AutoKalkulationsService.bilanz(ergebnisse)
        #expect(b.gruen == 1)
        #expect(b.gelb == 1)
        #expect(b.rot == 1)
        #expect(b.exportBereit == false)   // solange ROT existiert: kein Export
    }

    @Test @MainActor func rezeptAssistentSpeichertMachtPositionGruen() throws {
        // Ohne gelerntes Rezept ist die Position NICHT grün (kein voller Preis).
        // (Seit dem STLB-Katalog kann sie GELB sein — Richtwert statt blind ROT.)
        let pos = position("Betonwände herstellen", "m²")
        #expect(AutoKalkulationsService.bewerte(pos, in: ctx).status != .gruen)
        // Rezept über den Assistenten-Speicherweg anlegen (Aufwandswert)
        LeistungskatalogService.speichereRezept(auf: pos, maurer: 0.8, helfer: 0.4,
                                                quelle: "schätzung", in: ctx)
        // jetzt GRÜN mit Preis, und der Baustein ist gelernt (nächster gleiche Import trifft)
        let e = AutoKalkulationsService.bewerte(pos, in: ctx)
        #expect(e.status == .gruen)
        #expect(e.einheitspreisVK > 0)
        #expect(LeistungskatalogService.finde(leistung: "Betonwände herstellen", einheit: "m²", in: ctx) != nil)
    }

    @Test @MainActor func richtwertKatalogMachtRotZuGelb() throws {
        // Kein gelerntes Rezept, ABER der Aufwandswerte-Katalog kennt den Rohrgraben:
        // → GELB statt ROT, mit Richtwert-Meldung und echten Lohnstunden (kein 0-Preis).
        let pos = position("Rohrgraben ausheben", "m", menge: 320)
        let e = AutoKalkulationsService.bewerte(pos, in: ctx)
        #expect(e.status == .gelb)
        #expect(e.meldungen.contains { $0.contains("Richtwert") })
        #expect(e.meldungen.contains { $0.contains("Baggerfahrer") })
        // 0,30 h/m × 320 m = 96 Lohnstunden geschrieben → Preis > 0
        #expect(LVKalkulator.kalkuliere(position: pos).stundenGesamt == 96)
        #expect(e.einheitspreisVK > 0)
    }

    @Test func kolonneParsenUndTarifgruppe() {
        let r = LeistungskatalogService.parseKolonne("1 Baggerfahrer + 2 Rohrleger")
        #expect(r.count == 2)
        #expect(r[0].anzahl == 1 && r[0].rolle == "Baggerfahrer")
        #expect(r[1].anzahl == 2 && r[1].rolle == "Rohrleger")
        // Bereich + Slash-Rolle
        let r2 = LeistungskatalogService.parseKolonne("2-3 Betonbauer")
        #expect(r2.first?.anzahl == 2 && r2.first?.rolle == "Betonbauer")
        #expect(LeistungskatalogService.tarifgruppe(fuer: "Baggerfahrer") == .maschinist)
        #expect(LeistungskatalogService.tarifgruppe(fuer: "Helfer") == .helfer)
        #expect(LeistungskatalogService.tarifgruppe(fuer: "Rohrleger") == .facharbeiter)
    }

    @Test @MainActor func rollenpreiseStattAllesMaurer() throws {
        // Rohrgraben über STLB → Kolonne "1 Baggerfahrer + 1 Helfer", 0,30 h/m.
        let pos = position("Rohrgraben ausheben", "m", menge: 320)
        let e = AutoKalkulationsService.bewerte(pos, in: ctx)
        #expect(e.status == .gelb)
        // Lohn ist auf die echten Rollen verteilt, NICHT alles Maurer.
        let quals = Set(pos.lohnArray.compactMap { $0.qualifikation })
        #expect(quals.contains("Baggerfahrer"))
        #expect(quals.contains("Helfer"))
        #expect(!quals.contains("Maurer"))
        let kalk = LVKalkulator.kalkuliere(position: pos)
        // Gesamtstunden unverändert (0,30 × 320 = 96 Mannstunden).
        #expect(kalk.stundenGesamt == 96)
        // Lohnkosten je Einheit kleiner als „alles Maurer" (Helfer-Hälfte ist billiger).
        let allesMaurer = 0.30 * LeistungskatalogService.bruttoEK(fuer: "Maurer", in: ctx)
        #expect(kalk.lohnKosten < allesMaurer)
    }

    @Test @MainActor func exportBereitWennKeinRot() throws {
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        let ergebnisse = AutoKalkulationsService.fass(
            positionen: [position("Betonwände herstellen", "m²")], in: ctx)
        #expect(AutoKalkulationsService.bilanz(ergebnisse).exportBereit == true)
    }

    // MARK: - Tiefenkalkulation vorausfüllen (Station 3)

    /// Öffnet man die Kalkulation einer LEEREN Position, legt der Mops seinen Vorschlag ein.
    @Test @MainActor func vorfuellenLegtVorschlagInLeerePosition() throws {
        LeistungskatalogService.merke(leistung: "Betonwände herstellen", einheit: "m²",
                                      maurer: 0.8, helfer: 0.4, in: ctx)
        let pos = position("Betonwände herstellen", "m²")
        #expect(pos.lohnArray.isEmpty)   // vorher leer

        let gefuellt = AutoKalkulationsService.vorfuellenWennLeer(pos, in: ctx)
        #expect(gefuellt == true)
        #expect(!pos.lohnArray.isEmpty, "Der Vorschlag muss Lohn eingelegt haben.")
    }

    /// SICHERHEIT: eine Position mit von Hand eingetragenem Lohn wird NIE überschrieben.
    @Test @MainActor func vorfuellenLaesstBestehendeWerteInRuhe() throws {
        let pos = position("Sonderposition", "psch")
        let pl = PositionLohn(context: ctx)
        pl.id = UUID(); pl.qualifikation = "Facharbeiter"; pl.stunden = 0.5
        pl.stundenBruttoEK = 40; pl.position = pos
        #expect(pos.lohnArray.count == 1)

        let gefuellt = AutoKalkulationsService.vorfuellenWennLeer(pos, in: ctx)
        #expect(gefuellt == false, "Nicht-leere Position darf nicht angefasst werden.")
        #expect(pos.lohnArray.count == 1)
        #expect(pos.lohnArray.first?.stunden == 0.5)   // unverändert
    }
}
