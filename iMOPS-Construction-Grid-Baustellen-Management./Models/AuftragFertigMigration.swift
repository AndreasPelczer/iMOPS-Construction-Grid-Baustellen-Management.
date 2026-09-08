//
//  AuftragFertigMigration.swift
//  Versöhnt Bestandsdaten, in denen `status` und `isCompleted` auseinanderliefen.
//
//  Vorher gab es zwei Felder für denselben Zustand, und mehrere Pfade schrieben
//  nur eines davon: die Checklisten-Aktionen in `AuftragDetailView` setzten nur
//  `isCompleted`, `resetCompletion()` öffnete den Auftrag ohne den Status
//  zurückzunehmen, und `EditJobView` bot beides als getrennte Eingabefelder an.
//  Im Bestand liegen deshalb Aufträge mit widersprüchlichen Angaben.
//
//  **Konfliktregel (konservativ):** fertig ⇔ `status == .completed` ODER
//  `isCompleted == true`. Damit wird nie etwas „unfertig", das irgendwo als
//  erledigt markiert war — die Migration nimmt niemandem einen Haken weg.
//
//  Kein `UserDefaults`-Flag wie bei `ZuschlagMigration`: der Lauf ist billig
//  (das Prädikat holt nur die widersprüchlichen Datensätze, im Normalfall keinen)
//  und dadurch selbstheilend, falls doch je wieder etwas auseinanderläuft.
//

import Foundation
import CoreData

enum AuftragFertigMigration {

    /// Holt genau die Aufträge, bei denen die beiden Felder sich widersprechen.
    ///
    /// Als Prädikat und nicht in Swift gefiltert, damit im Normalfall (nichts
    /// divergiert) gar keine Objekte geladen werden.
    static func widerspruechlich() -> NSFetchRequest<Auftrag> {
        let fertig = AuftragStatus.completed.rawValue
        let request: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        request.predicate = NSPredicate(
            format: "(isCompleted == YES AND statusRawValue != %@) OR (isCompleted == NO AND statusRawValue == %@)",
            fertig, fertig)
        return request
    }

    /// Versöhnt die Widersprüche und liefert die Anzahl geänderter Datensätze.
    ///
    /// Idempotent: nach dem ersten Lauf findet das Prädikat nichts mehr, ein
    /// zweiter Lauf liefert 0. Speichert nur, wenn es wirklich etwas zu speichern
    /// gibt — sonst wäre `hasChanges` an anderer Stelle nicht mehr aussagekräftig.
    @discardableResult
    static func versoehne(in context: NSManagedObjectContext) -> Int {
        guard let auftraege = try? context.fetch(widerspruechlich()), !auftraege.isEmpty else {
            return 0
        }

        for auftrag in auftraege {
            // ODER-Regel: eine der beiden Quellen sagt „fertig" → fertig.
            // `setzeFertig(true)` setzt den Status; das Legacy-Feld zieht der
            // Setter in `Auftrag.swift` mit. `false` kommt hier nie vor: das
            // Prädikat liefert nur Fälle, in denen mindestens eine Seite fertig
            // sagt.
            auftrag.setzeFertig(true)
        }

        do {
            if context.hasChanges { try context.save() }
        } catch {
            // Nicht schlucken: beim nächsten Start läuft es erneut, aber der
            // Grund gehört ins Log, sonst bleibt der Widerspruch unsichtbar.
            print("AuftragFertigMigration fehlgeschlagen: \(error)")
            return 0
        }
        return auftraege.count
    }

    /// Boot-Pfad. Loggt, wie viele Datensätze versöhnt wurden — eine stille
    /// Migration ist eine, von der niemand weiß, dass sie etwas verändert hat.
    static func run(in context: NSManagedObjectContext) {
        let anzahl = versoehne(in: context)
        if anzahl > 0 {
            print("AuftragFertigMigration: \(anzahl) Auftrag/Aufträge versöhnt "
                + "(status und isCompleted liefen auseinander).")
        }
    }
}
