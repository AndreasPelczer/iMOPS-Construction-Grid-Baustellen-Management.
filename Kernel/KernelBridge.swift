//
//  KernelBridge.swift
//  test25B
//
//  Phase 3: Verbindet CoreData-Aufträge mit dem iMOPS Kernel.
//  Jeder Auftrag wird als ^TASK im Kernel registriert,
//  damit der Meier-Score (JOSHUA-Matrix) live berechnet wird.
//

import Foundation
import CoreData

@MainActor
final class KernelBridge {
    static let shared = KernelBridge()
    private init() {}

    // MARK: - Job ↔ Kernel ID

    /// Erzeugt eine stabile Kernel-ID aus der CoreData ObjectID
    func jobKernelID(_ auftrag: Auftrag) -> String? {
        guard auftrag.objectID.isTemporaryID == false else { return nil }
        // Letztes Segment der URI ist z.B. "p12" – stabil und eindeutig
        return auftrag.objectID.uriRepresentation().lastPathComponent
    }

    // MARK: - Register (Neuer Auftrag)

    /// Registriert einen CoreData-Auftrag im Kernel als ^TASK
    func registerJob(_ auftrag: Auftrag) {
        guard let id = jobKernelID(auftrag) else {
            print("iMOPS-BRIDGE: Kann temporäre ObjectID nicht registrieren")
            return
        }

        let title = auftrag.processingDetails ?? "Auftrag"

        // Gewicht berechnen: Basis 10 + 5 pro Produktionsposition
        let extras = AuftragExtrasPayload.from(auftrag.extras)
        let weight = 10 + (extras.lineItems.count * 5)

        KernelTaskRepository.createProductionTask(
            id: id,
            title: title,
            weight: weight
        )

        // ChefIQ PINS synchronisieren (falls Allergene vorhanden)
        if !extras.allergenSummary.isEmpty {
            syncChefIQPins(auftrag, allergens: extras.allergenSummary, nutrition: extras.nutritionSnapshot)
        }

        print("iMOPS-BRIDGE: Job '\(title)' registriert (id: \(id), weight: \(weight))")
    }

    // MARK: - Status Sync

    /// Synchronisiert einen Status-Wechsel mit dem Kernel
    func syncStatus(_ auftrag: Auftrag, newStatus: AuftragStatus) {
        guard let id = jobKernelID(auftrag) else { return }

        switch newStatus {
        case .pending:
            // Zurück auf OPEN → Kernel reaktivieren falls nötig
            let existing: String? = iMOPS.GET(.task(id, "STATUS"))
            if existing == nil {
                // Task wurde bereits archiviert, neu registrieren
                registerJob(auftrag)
            } else {
                iMOPS.SET(.task(id, "STATUS"), "OPEN")
            }

        case .inProgress:
            iMOPS.SET(.task(id, "STATUS"), "OPEN") // OPEN = aktiv für Meier-Score
            // Timer starten
            auftrag.lastStartTime = Date()

        case .onHold:
            iMOPS.SET(.task(id, "STATUS"), "ON_HOLD")
            // Timer stoppen, Zeit akkumulieren
            if let start = auftrag.lastStartTime {
                let elapsed = Date().timeIntervalSince(start)
                auftrag.totalProcessingTime += elapsed
                auftrag.lastStartTime = nil
            }

        case .completed:
            // Timer stoppen falls noch laufend
            if let start = auftrag.lastStartTime {
                let elapsed = Date().timeIntervalSince(start)
                auftrag.totalProcessingTime += elapsed
                auftrag.lastStartTime = nil
            }
            // Kernel-Task archivieren und löschen
            KernelTaskRepository.completeTask(id: id)
            print("iMOPS-BRIDGE: Job \(id) abgeschlossen und archiviert")
        }
    }

    // MARK: - Remove (Löschen)

    /// Entfernt einen Auftrag komplett aus dem Kernel
    func removeJob(_ auftrag: Auftrag) {
        guard let id = jobKernelID(auftrag) else { return }
        iMOPS.KILLTREE(.task(id, ""))
        print("iMOPS-BRIDGE: Job \(id) aus Kernel entfernt")
    }

    // MARK: - Warm-Start (App-Launch)

    /// Lädt alle aktiven Aufträge beim App-Start in den Kernel
    func syncAllActiveJobs(from context: NSManagedObjectContext) {
        let request: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")

        do {
            let activeJobs = try context.fetch(request)
            for job in activeJobs {
                registerJob(job)
            }
            print("iMOPS-BRIDGE: Warm-Start abgeschlossen. \(activeJobs.count) aktive Jobs im Kernel.")
        } catch {
            print("iMOPS-BRIDGE: Warm-Start Fehler: \(error)")
        }
    }

    // MARK: - ChefIQ PINS Sync

    /// Synchronisiert Allergen- und Nährstoffdaten als Kernel-PINS
    func syncChefIQPins(_ auftrag: Auftrag, allergens: [String], nutrition: NutritionSnapshot?) {
        guard let id = jobKernelID(auftrag) else { return }

        var medicalString = "ALLERGENE: \(allergens.joined(separator: ","))"
        if let n = nutrition {
            medicalString += " | BE: \(n.beValue) | kcal: \(n.calories)"
        }
        iMOPS.SET(.task(id, "PINS.MEDICAL"), medicalString)

        print("iMOPS-BRIDGE: ChefIQ-PINS für \(id) gesetzt: \(medicalString)")
    }
}
