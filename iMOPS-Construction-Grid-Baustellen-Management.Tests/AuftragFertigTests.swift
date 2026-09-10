//
//  AuftragFertigTests.swift
//  Eine Quelle für „fertig" — `status` ist die Wahrheit, `isCompleted` folgt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AuftragFertigTests {

    // Instanz-Property, nicht inline (struct — siehe CLAUDE.md).
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func macheAuftrag(_ bezeichnung: String = "Wand mauern") -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = bezeichnung
        a.status = .pending
        a.storageNote = ""
        return a
    }

    // MARK: - Die eine Quelle

    @Test @MainActor func istFertigFolgtDemStatus() {
        let a = macheAuftrag()
        #expect(a.istFertig == false)
        a.status = .completed
        #expect(a.istFertig == true)
        a.status = .inProgress
        #expect(a.istFertig == false)
    }

    /// Das Legacy-Feld wird vom Setter mitgezogen — nicht mehr von Hand geschrieben.
    @Test @MainActor func statusSetterZiehtDasLegacyFeldMit() {
        let a = macheAuftrag()
        #expect(a.isCompleted == false)
        a.status = .completed
        #expect(a.isCompleted == true)
        a.status = .onHold
        #expect(a.isCompleted == false)
    }

    // MARK: - setzeFertig

    /// „Nicht mehr fertig" stuft nur herab, was fertig war — ein Auftrag auf
    /// `.pending` bleibt `.pending`, wenn jemand einen Checklistenpunkt anlegt.
    @Test @MainActor func setzeFertigFalseLaesstOffeneAuftraegeInRuhe() {
        let a = macheAuftrag()
        a.status = .pending
        a.setzeFertig(false)
        #expect(a.status == .pending)

        a.status = .onHold
        a.setzeFertig(false)
        #expect(a.status == .onHold)
    }

    /// Der alte Bug in `resetCompletion()`: dort wurde `isCompleted = false`
    /// gesetzt, `status` blieb aber auf `.completed` stehen — der Auftrag war
    /// „geöffnet" und galt gleichzeitig als fertig.
    @Test @MainActor func auftragWiederOeffnenNimmtDenStatusZurueck() {
        let a = macheAuftrag()
        a.status = .completed
        #expect(a.istFertig == true)

        a.setzeFertig(false)

        #expect(a.istFertig == false)
        #expect(a.status == .inProgress)
        #expect(a.isCompleted == false)
    }

    // MARK: - Schreibpfad

    @Test @MainActor func jobViewModelSetztNurDenStatus() {
        let a = macheAuftrag()
        let vm = JobViewModel(job: a, context: ctx)

        vm.setStatus(.completed)
        #expect(a.status == .completed)
        #expect(a.istFertig == true)
        #expect(a.isCompleted == true)   // vom Setter mitgezogen

        vm.setStatus(.inProgress)
        #expect(a.istFertig == false)
        #expect(a.isCompleted == false)
    }

    // MARK: - Backfill

    /// (a) Nur das Legacy-Feld sagt fertig — kommt aus den Checklisten-Aktionen,
    /// die früher `isCompleted` setzten, ohne den Status anzufassen.
    @Test @MainActor func backfillZiehtStatusNachWennNurDasFlagFertigSagt() throws {
        let a = macheAuftrag()
        a.status = .inProgress
        a.setValue(true, forKey: "isCompleted")   // am Setter vorbei: Bestandsdatensatz
        try ctx.save()
        #expect(a.istFertig == false)

        let anzahl = AuftragFertigMigration.versoehne(in: ctx)

        #expect(anzahl == 1)
        #expect(a.istFertig == true)
        #expect(a.status == .completed)
    }

    /// (b) Nur der Status sagt fertig — kommt aus `resetCompletion()` und Co.
    @Test @MainActor func backfillGleichtDasFlagAnWennNurDerStatusFertigSagt() throws {
        let a = macheAuftrag()
        a.setValue(AuftragStatus.completed.rawValue, forKey: "statusRawValue")
        a.setValue(false, forKey: "isCompleted")
        try ctx.save()

        let anzahl = AuftragFertigMigration.versoehne(in: ctx)

        #expect(anzahl == 1)
        #expect(a.istFertig == true)
        #expect(a.isCompleted == true)
    }

    /// (c) Idempotenz — der zweite Lauf ändert nichts mehr.
    @Test @MainActor func backfillIstIdempotent() throws {
        let a = macheAuftrag()
        a.status = .inProgress
        a.setValue(true, forKey: "isCompleted")
        let b = macheAuftrag("Zweiter")
        b.setValue(AuftragStatus.completed.rawValue, forKey: "statusRawValue")
        b.setValue(false, forKey: "isCompleted")
        try ctx.save()

        #expect(AuftragFertigMigration.versoehne(in: ctx) == 2)
        #expect(AuftragFertigMigration.versoehne(in: ctx) == 0)
        #expect(AuftragFertigMigration.versoehne(in: ctx) == 0)
    }

    /// Die Konfliktregel ist konservativ: sie nimmt niemandem einen Haken weg.
    @Test @MainActor func backfillMachtNichtsUnfertig() throws {
        let a = macheAuftrag()
        a.status = .inProgress
        a.setValue(true, forKey: "isCompleted")
        try ctx.save()

        AuftragFertigMigration.versoehne(in: ctx)

        #expect(a.istFertig == true, "Ein gesetzter Haken darf nicht verschwinden.")
    }

    /// Saubere Datensätze rührt der Backfill nicht an.
    @Test @MainActor func backfillLaesstStimmigeAuftraegeInRuhe() throws {
        let offen = macheAuftrag("Offen")
        let fertig = macheAuftrag("Fertig")
        fertig.status = .completed
        try ctx.save()

        #expect(AuftragFertigMigration.versoehne(in: ctx) == 0)
        #expect(offen.istFertig == false)
        #expect(fertig.istFertig == true)
    }
}
