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

    // MARK: - Fortschritt-Ableitung (Welle 5.2.1)

    @Test @MainActor func gemessenerFortschritt() {
        let p = makePosition(menge: 240)
        addAufmass(to: p, menge: 216)
        #expect(p.gemessenerFortschrittProzent == 90)
    }

    @Test @MainActor func gemessenerFortschrittMehrmengeOhneCap() {
        let p = makePosition(menge: 240)
        addAufmass(to: p, menge: 300)
        #expect(p.gemessenerFortschrittProzent == 125)   // R2.b: kein Capping
    }

    @Test @MainActor func gemessenerFortschrittOhneSoll() {
        let p = makePosition(menge: 0)
        addAufmass(to: p, menge: 50)
        #expect(p.gemessenerFortschrittProzent == nil)   // R2.a: keine Division durch 0
    }

    @Test @MainActor func displayedFortschrittAbleitung() {
        let leer = makePosition(menge: 240)
        #expect(leer.displayedFortschritt(manuellerProzent: nil) == .unbestimmt)
        #expect(leer.displayedFortschritt(manuellerProzent: 50) == .geschaetzt(prozent: 50))

        let gemessen = makePosition(menge: 240)
        addAufmass(to: gemessen, menge: 240)
        #expect(gemessen.displayedFortschritt(manuellerProzent: 80) == .gemessen(prozent: 100))
    }

    // MARK: - BuildIQ-Buchung (Welle 5.3.2)

    /// Eine BuildIQ-Buchung landet als Aufmaß-Zeile mit quelle == .buildiq (Option B2)
    /// und zählt neben manuellen Aufmaßen in dieselbe Ist-Summe. Spiegelt, was
    /// BuildIQBuchungBestaetigenView.buchen() im Modell tut. Bewusst OHNE ctx.save()
    /// (wie die Summen-/Ampel-Tests) — der geteilte Context wird nicht geflusht.
    @Test @MainActor func buildIQBuchungZaehltAlsIst() {
        let pos = makePosition(menge: 100)

        // manuelles Aufmaß (bestehende Quelle)
        addAufmass(to: pos, menge: 40)

        // BuildIQ-Buchung: Menge aus dem Scan, quelle = .buildiq
        let scan = Aufmass(context: ctx)
        scan.id = UUID()
        scan.istMenge = 55
        scan.istEinheit = "m²"
        scan.notiz = "BuildIQ: 312 Baugrubenaushub"
        scan.quelle = .buildiq
        scan.erstelltAm = Date()
        scan.lvPosition = pos

        // B2: beide Quellen zählen in dieselbe Ist-Summe.
        #expect(abs(pos.istMengeSumme - 95) < 0.0001)
        #expect(pos.aufmassArray.count == 2)
        #expect(pos.aufmassAmpel == .gruen)          // 5 % Abweichung ≤ 5 %

        // Die BuildIQ-Zeile ist als solche gekennzeichnet.
        #expect(scan.quelle == .buildiq)
        #expect(pos.aufmassArray.contains { $0.quelle == .buildiq })
    }

    // MARK: - Loesch-Folgen (Sicherheitsabfrage)

    @Test @MainActor func loeschFolgenLeerIstNil() {
        let p = makePosition(menge: 100)
        #expect(p.loeschFolgen == nil)
    }

    @Test @MainActor func loeschFolgenMitAufmass() {
        let p = makePosition(menge: 100)
        addAufmass(to: p, menge: 60)
        addAufmass(to: p, menge: 60)
        addAufmass(to: p, menge: 60)
        let f = p.loeschFolgen
        #expect(f?.contains("3 Aufmaß") == true)
        #expect(f?.contains("180") == true)
    }
}
