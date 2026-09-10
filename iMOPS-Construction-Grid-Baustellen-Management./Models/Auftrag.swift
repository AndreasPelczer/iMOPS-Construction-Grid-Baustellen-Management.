// Models/Auftrag.swift
//
// EINE Quelle für „fertig".
//
// Der Auftrag trug zwei Felder für denselben Zustand: `statusRawValue` (Enum
// `AuftragStatus`) und `isCompleted: Bool`. Sie liefen auseinander — die
// Checklisten-Aktionen in `AuftragDetailView` setzten nur `isCompleted`, nie
// `status`; `resetCompletion()` öffnete den Auftrag, ließ `status` aber auf
// `.completed` stehen. Grap8 (`Service/Kausalkette.swift`) musste deshalb beide
// Felder prüfen — eine Krücke, die hier abgelöst wird.
//
// Ab jetzt gilt:
//   • `status` ist die Wahrheit.
//   • `istFertig` ist die EINE Stelle, die die Frage beantwortet.
//   • `isCompleted` bleibt als Legacy-Feld erhalten (Schema unverändert), wird
//     aber von keinem Pfad mehr direkt geschrieben — nur noch vom Setter unten
//     mitgezogen. Rauswerfen braucht eine neue Modellversion; eigener Branch.

import Foundation

extension Auftrag {

    /// Master-Status für die UI (AuftragStatus).
    ///
    /// Der Setter zieht das Legacy-Feld `isCompleted` mit. `statusRawValue` wird
    /// nirgends sonst geschrieben (geprüft) — damit ist dies die einzige Tür, und
    /// jeder bestehende `job.status = …`-Pfad wird automatisch konsistent.
    var status: AuftragStatus {
        get {
            AuftragStatus(rawValue: statusRawValue ?? AuftragStatus.pending.rawValue) ?? .pending
        }
        set {
            statusRawValue = newValue.rawValue
            let fertig = (newValue == .completed)
            // Nur schreiben, wenn nötig: sonst meldet Core Data eine Änderung,
            // wo keine ist, und `hasChanges` wird unbrauchbar.
            if isCompleted != fertig { isCompleted = fertig }
        }
    }

    /// Ist dieser Auftrag fertig? **Die einzige Stelle, die das beantwortet.**
    var istFertig: Bool { status == .completed }

    /// Fertig-Zustand setzen, ohne den übrigen Status zu verlieren.
    ///
    /// „Nicht mehr fertig" stuft bewusst nur herab, wenn der Auftrag als fertig
    /// galt — ein Auftrag auf `.pending` bleibt `.pending`, wenn jemand einen
    /// Checklistenpunkt hinzufügt. Das Ziel beim Öffnen ist `.inProgress`, wie es
    /// `KausalbauketteView` beim Umschalten schon immer gemacht hat.
    func setzeFertig(_ fertig: Bool) {
        if fertig {
            status = .completed
        } else if status == .completed {
            status = .inProgress
        }
    }

    /// Kompatibilität: falls irgendwo noch JobStatus verwendet wird
    /// (JobStatus ist ein typealias auf AuftragStatus).
    var jobStatus: JobStatus {
        get { status }
        set { status = newValue }
    }
}
