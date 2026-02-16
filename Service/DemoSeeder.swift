//
//  DemoSeeder.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.01.26.
//


import Foundation
import CoreData

/// Legt ein privates Demo-/Test-Event an, damit du das System "in sich" testen kannst.
/// Event = "App schreiben (Systemtest)"
/// Jobs/Aufträge = MEP + Vorbereitungs-/Produktions-/Ausgabe-Aufträge.
///
/// Wichtig:
/// - Wird nur angelegt, wenn es dieses Demo-Event noch nicht gibt.
/// - Nutzt Event.extras für eine kleine Checkliste (wie in EventDetailView).
enum DemoSeeder {

    /// Eindeutiger "Key" für das Demo-Event (damit wir es nicht doppelt anlegen)
    private static let demoEventNumber = "DEMO-APP-001"

    static func seedIfNeeded(into context: NSManagedObjectContext) {
        // 1) Prüfen: gibt es das Demo-Event schon?
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "eventNumber == %@", demoEventNumber)

        let existing = (try? context.fetch(req))?.first
        if existing != nil {
            print("ℹ️ DemoSeeder: Demo-Event existiert schon. Nichts zu tun.")
            return
        }

        // 2) Event anlegen
        let event = Event(context: context)

        // Zeiten (du kannst die später in der UI ändern)
        // Setup: jetzt, Start: +2h, Ende: +8h
        let now = Date()
        event.setupTime = now
        event.eventStartTime = Calendar.current.date(byAdding: .hour, value: 2, to: now)
        event.eventEndTime = Calendar.current.date(byAdding: .hour, value: 8, to: now)

        event.title = "App schreiben (Systemtest)"
        event.eventNumber = demoEventNumber
        event.location = "Eigene Küche / Testumgebung"
        event.notes = """
Das ist ein privates Test-Event, um das System realistisch zu testen.

Event = Arbeitstag
Aufträge = Arbeitsblöcke (MEP, Produktion, Ausgabe)
Schritte/Tasks kommen später – vorerst nutzen wir:
- Event-Checkliste (Extras)
- mehrere Aufträge
"""
        event.timeStamp = now

        // 3) Event-Extras (Checkliste) setzen – nutzt die Structs aus EventDetailView.swift
        //    (EventExtrasPayload + ChecklistItem sind bei dir im Projekt global definiert)
        var extras = EventExtrasPayload()
        extras.checklist = [
            EventChecklistItem(title: "MEP-Liste erstellen (damit nichts fehlt)"),
            EventChecklistItem(title: "Kühlkette & Lager prüfen"),
            EventChecklistItem(title: "GN-Bleche/Deckel/Etiketten bereitstellen"),
            EventChecklistItem(title: "Thermometer / Timer / Wagen checken"),
            EventChecklistItem(title: "Übergabe & Verantwortlichkeiten klären")
        ]

        do {
            let data = try JSONEncoder().encode(extras)
            event.extras = String(data: data, encoding: .utf8)
        } catch {
            print("⚠️ DemoSeeder: Konnte Event.extras nicht encoden: \(error)")
        }

        // 4) Aufträge (Jobs) anlegen
        // MEP-Auftrag
        addJob(
            into: context,
            event: event,
            employeeName: "Andreas",
            status: .inProgress,
            storageLocation: "Bereitstelle",
            storageNote: "1/1 Silber 6,5 cm",
            isHotDelivery: false,
            processingDetails: """
MEP – damit nichts fehlt

- Ware holen
- Bleche belegen
- Beschriften
- zurück in die Kühlkette (Übergabe-ready)
"""
        )

        // Produktion: Spätzle
        addJob(
            into: context,
            event: event,
            employeeName: "Andreas",
            status: .pending,
            storageLocation: "Bereitstelle",
            storageNote: "1/1 Silber 6,5 cm",
            isHotDelivery: true,
            processingDetails: """
Produktion: Spätzle (Kantine)

- in Butter leicht anbraten
- GN 1/1 6,5 cm
- ca. 5 cm hoch pro Blech
- in Hordenwagen
- Gar-/Warmhalteparameter notieren
"""
        )

        // Ausgabe
        addJob(
            into: context,
            event: event,
            employeeName: "Andreas",
            status: .pending,
            storageLocation: "Bereitstelle",
            storageNote: "1/1 Silber",
            isHotDelivery: true,
            processingDetails: """
VA: Essensausgabe Kantine 12–15 Uhr

- Ausgabe-Station aufbauen
- Beschilderung/Allergene bereitstellen
- Nachproduktion/Refill planen
- Ende: Reste / Doku / Reinigung
"""
        )

        // 5) Speichern
        do {
            try context.save()
            print("✅ DemoSeeder: Demo-Event + Aufträge angelegt.")
        } catch {
            print("❌ DemoSeeder: Fehler beim Speichern: \(error)")
        }
    }

    // MARK: - Helper

    private static func addJob(
        into context: NSManagedObjectContext,
        event: Event,
        employeeName: String,
        status: JobStatus,
        storageLocation: String,
        storageNote: String,
        isHotDelivery: Bool,
        processingDetails: String
    ) {
        let job = Auftrag(context: context)
        job.event = event

        job.employeeName = employeeName
        job.status = status
        job.isCompleted = (status == .completed)

        job.storageLocation = storageLocation
        job.storageNote = storageNote
        job.deliveryTemperature = isHotDelivery

        job.processingDetails = processingDetails

        // Timer-Felder (Standard)
        job.totalProcessingTime = 0
        job.lastStartTime = nil
    }
}
