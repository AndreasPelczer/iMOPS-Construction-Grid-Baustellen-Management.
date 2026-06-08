//
//  AufmassTests.swift
//  iMOPS-Construction-Grid-Baustellen-Management.Tests
//
//  Welle 5.1 — Aufmass-Entity + Soll/Ist-Skelett.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AufmassTests {

    /// EIN In-Memory-CoreData-Stack, dauerhaft festgehalten (struct → statischer
    /// Halter, sonst gibt der Container die Objekte sofort frei). Siehe CLAUDE.md.
    @MainActor
    private static let testController = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { Self.testController.container.viewContext }

    @MainActor
    private func makePosition(menge: Double) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.posNr = "3.30.1"
        pos.bezeichnung = "Außenwand Porenbeton"
        pos.menge = menge
        pos.einheit = "m²"
        return pos
    }

    /// Der Core-Data-Stack lädt mit der neuen Entity, und ein Aufmass lässt sich
    /// anlegen, speichern und wieder laden — inkl. greifender Inverse-Beziehung.
    @Test @MainActor func aufmassSpeichernUndLaden() throws {
        let pos = makePosition(menge: 28.42)

        let a = Aufmass(context: ctx)
        a.id = UUID()
        a.istMenge = 27.9
        a.istEinheit = "m²"
        a.erstelltAm = Date(timeIntervalSince1970: 1_700_000_000)
        a.quelle = .manuell
        a.notiz = "EG, Außenwand West"
        a.lvPosition = pos

        try ctx.save()

        // Über Prädikat laden (robust gegen Objekte anderer Tests im geteilten Stack).
        let req = Aufmass.fetchRequest()
        req.predicate = NSPredicate(format: "notiz == %@", "EG, Außenwand West")
        let geladen = try ctx.fetch(req)

        #expect(geladen.count == 1)
        #expect(geladen.first?.istMenge == 27.9)
        #expect(geladen.first?.quelle == .manuell)
        #expect(geladen.first?.lvPosition?.posNr == "3.30.1")
        // Inverse greift: die Position kennt ihr Aufmaß.
        #expect(pos.aufmassArray.contains { $0.notiz == "EG, Außenwand West" })
    }

    /// Position ohne Aufmaß: Abweichung == Soll, hatAufmass == false.
    @Test @MainActor func ohneAufmassIstAbweichungGleichSoll() {
        let pos = makePosition(menge: 50)
        #expect(pos.hatAufmass == false)
        #expect(pos.istMengeSumme == 0)
        #expect(pos.sollMenge == 50)
        #expect(pos.abweichung == 50)
    }

    /// Mehrere Aufmaße: Summe + Abweichung + Prozent korrekt.
    @Test @MainActor func mehrereAufmasseSummieren() {
        let pos = makePosition(menge: 100)
        for m in [30.0, 25.0, 20.0] {
            let a = Aufmass(context: ctx)
            a.id = UUID()
            a.istMenge = m
            a.erstelltAm = Date()
            a.lvPosition = pos
        }
        #expect(pos.hatAufmass)
        #expect(pos.aufmassArray.count == 3)
        #expect(abs(pos.istMengeSumme - 75) < 0.0001)
        #expect(abs(pos.abweichung - 25) < 0.0001)
        #expect(abs(pos.abweichungProzent - 0.25) < 0.0001)
    }

    /// quelleRaw <-> AufmassQuelle round-trippt verlustfrei; Default = manuell.
    @Test @MainActor func quelleRoundTrip() {
        let a = Aufmass(context: ctx)
        a.quelle = .importiert
        #expect(a.quelleRaw == "importiert")
        a.quelleRaw = nil
        #expect(a.quelle == .manuell)       // fehlende Quelle → defensiv manuell
        a.quelleRaw = "buildiq"
        #expect(a.quelle == .buildiq)
    }

    // MARK: - Ampel (Welle 5.2)

    @MainActor
    private func addAufmass(to pos: LVPosition, menge: Double) {
        let a = Aufmass(context: ctx)
        a.id = UUID()
        a.istMenge = menge
        a.erstelltAm = Date()
        a.lvPosition = pos
    }

    @Test @MainActor func ampelOhneAufmassIstGrau() {
        let pos = makePosition(menge: 100)
        #expect(pos.aufmassAmpel == .keinAufmass)
    }

    @Test @MainActor func ampelNachAbweichung() {
        let exakt = makePosition(menge: 100)
        addAufmass(to: exakt, menge: 100)
        #expect(exakt.aufmassAmpel == .gruen)      // 0 % Abweichung

        let knapp = makePosition(menge: 100)
        addAufmass(to: knapp, menge: 97)
        #expect(knapp.aufmassAmpel == .gruen)      // 3 % ≤ 5 %

        let mittel = makePosition(menge: 100)
        addAufmass(to: mittel, menge: 90)
        #expect(mittel.aufmassAmpel == .orange)    // 10 % ≤ 15 %

        let weit = makePosition(menge: 100)
        addAufmass(to: weit, menge: 70)
        #expect(weit.aufmassAmpel == .rot)         // 30 % > 15 %
    }
}
