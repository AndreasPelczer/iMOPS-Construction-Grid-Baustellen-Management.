//
//  iMOPS_Construction_Grid_Baustellen_ManagementTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct iMOPS_Construction_Grid_Baustellen_ManagementTests {

    /// EIN In-Memory-CoreData-Stack für alle Tests, dauerhaft festgehalten.
    /// Wichtig: `PersistenceController` ist ein struct — ein inline erzeugter
    /// `PersistenceController(inMemory: true)` wird nach der Zeile freigegeben,
    /// der `viewContext` hält den Container nicht am Leben. Darum hier ein
    /// statischer Halter.
    @MainActor
    private static let testController = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { Self.testController.container.viewContext }

    @Test func appLaunches() async throws {
        // Basic smoke test
        #expect(true)
    }

    // MARK: - LV-Export (Regression: Share-Sheet war leer / weiß)

    /// Baut einen frischen In-Memory-Event mit einer LV-Position.
    @MainActor
    private func makeEventMitPosition() -> (Event, [LVPosition]) {
        let event = Event(context: ctx)
        event.title = "Test-Baustelle"
        event.eventNumber = "TEST-001"

        let pos = LVPosition(context: ctx)
        pos.posNr = "3.20.1"
        pos.bezeichnung = "Streifenfundament"
        pos.menge = 33
        pos.einheit = "m"
        pos.kostenGruppeNummer = "320"
        pos.event = event

        return (event, [pos])
    }

    /// Der LV-PDF-Export muss valide, nicht-leere PDF-Daten liefern.
    /// Schließt die Verdachts-Ursache "Share-Sheet leer, weil Daten leer" aus.
    @Test @MainActor func lvPDFExportLiefertValidePDF() {
        let (event, positionen) = makeEventMitPosition()
        let data = LVPDFExporter.generate(event: event, positionen: positionen)

        #expect(!data.isEmpty)
        // PDF-Dateien beginnen mit der Signatur "%PDF"
        #expect(data.prefix(4) == Data("%PDF".utf8))
    }

    /// Der LV-CSV-Export liefert nicht-leeren Text mit Header + Positions-Bezeichnung.
    @Test @MainActor func lvCSVExportEnthaeltPosition() {
        let (event, positionen) = makeEventMitPosition()
        let data = LVCSVExporter.generate(event: event, positionen: positionen)
        let text = String(decoding: data, as: UTF8.self)

        #expect(!data.isEmpty)
        #expect(text.contains("PosNr"))               // Header-Zeile
        #expect(text.contains("Streifenfundament"))   // Datenzeile
    }

    // MARK: - Pauschal-Preisträger (Regression: Kostenzusammenfassung/Export = 0,00 €)

    /// Baut eine Goldschmitt-Pauschalposition exakt wie der MarktbreitSeeder:
    /// Preis als NU-Material-Unterposition, WG/BGK = 0.
    @MainActor
    private func makePauschalPosition(netto: Double) -> LVPosition {
        let event = Event(context: ctx)
        event.title = "Schwarz Marktbreit"

        let pos = LVPosition(context: ctx)
        pos.posNr = "3.90.1"
        pos.bezeichnung = "Baustelleneinrichtung"
        pos.kostenGruppeNummer = "390"
        pos.einheit = "psch"
        pos.menge = 1
        pos.wagnisGewinnProzent = 0
        pos.bgkProzent = 0
        pos.event = event

        let m = PositionMaterial(context: ctx)
        m.id = UUID()
        m.materialName = "Fremdleistung NU Goldschmitt"
        m.mengeProEinheit = 1
        m.einzelpreis = netto
        m.verschnittProzent = 0
        m.einheit = "psch"
        m.position = pos

        return pos
    }

    /// Ohne erfasstes Angebot muss der Resolver auf den kalkulierten VK-Preis
    /// (= Pauschal-Träger) zurückfallen — nicht 0 liefern.
    @Test @MainActor func effektiverEPNutztPauschalTraeger() {
        let pos = makePauschalPosition(netto: 1549.21)
        let ep = LVKalkulator.effektiverEP(for: pos)
        #expect(abs(ep - 1549.21) < 0.001)
    }

    /// Die Netto-Summe (wie sie Kostenzusammenfassung/PDF/XRechnung bilden)
    /// muss für die Pauschalposition > 0 sein — Regression war 0,00 €.
    @Test @MainActor func pauschalNettoSummeGroesserNull() {
        let pos = makePauschalPosition(netto: 1549.21)
        let netto = [pos].reduce(0.0) { $0 + LVKalkulator.effektiverEP(for: $1) * $1.menge }
        #expect(netto > 0)
        #expect(abs(netto - 1549.21) < 0.001)
    }

    /// DER wichtige Test fürs Geld: Eine Position OHNE Preisträger und OHNE
    /// Angebot fällt deterministisch auf 0 — und genau dieses `== 0` ist das
    /// "fehlt"-Signal, das die Export-Gates auswerten (XRechnung blockt hart,
    /// GAEB/Kostenübersicht warnen). Bricht dieser Test, ist die stille
    /// 0-€-Falle zurück: eine künftige Pauschale ohne Träger würde wieder
    /// unbemerkt mit 0 € durchrutschen.
    @Test @MainActor func positionOhnePreisFaelltAufNull() {
        let event = Event(context: ctx)
        event.title = "Schwarz Marktbreit"

        let pos = LVPosition(context: ctx)
        pos.posNr = "3.90.9"
        pos.bezeichnung = "Pauschale OHNE Preisträger"
        pos.kostenGruppeNummer = "390"
        pos.einheit = "psch"
        pos.menge = 1
        pos.event = event
        // bewusst: kein PositionMaterial / keine Kalkulation, kein Angebot

        #expect(!pos.hatKalkulation)                       // nachweislich kein Träger
        #expect(LVKalkulator.effektiverEP(for: pos) == 0)  // → fällt (laut prüfbar) auf 0
    }
}
