import Foundation
import CoreData

/// Legt eine Demo-Baustelle an, damit das System realistisch getestet werden kann.
enum DemoSeeder {

    private static let demoEventNumber = "DEMO-BAU-001"

    static func seedIfNeeded(into context: NSManagedObjectContext) {
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "eventNumber == %@", demoEventNumber)

        if (try? context.fetch(req))?.first != nil {
            return
        }

        let now = Date()
        let event = Event(context: context)
        event.setupTime = now
        event.eventStartTime = Calendar.current.date(byAdding: .day, value: 1, to: now)
        event.eventEndTime = Calendar.current.date(byAdding: .day, value: 90, to: now)

        event.title = "Neubau Mehrfamilienhaus Lindenstrasse 12"
        event.eventNumber = demoEventNumber
        event.location = "Lindenstrasse 12, 60325 Frankfurt"
        event.notes = """
Demo-Baustelle: 6 Wohneinheiten, 3 Geschosse.
Bauherr: Mustermann GmbH
Architekt: Planbuero Schmidt
"""
        event.timeStamp = now

        var extras = EventExtrasPayload()
        extras.checklist = [
            EventChecklistItem(title: "Baugenehmigung pruefen"),
            EventChecklistItem(title: "Baustromkasten anschliessen"),
            EventChecklistItem(title: "Bauzaun aufstellen"),
            EventChecklistItem(title: "Container (Buero + Sanitaer) liefern"),
            EventChecklistItem(title: "Sicherheitsunterweisung alle Gewerke")
        ]

        do {
            let data = try JSONEncoder().encode(extras)
            event.extras = String(data: data, encoding: .utf8)
        } catch {
            print("DemoSeeder: Konnte Event.extras nicht encoden: \(error)")
        }

        // Auftrag 1: Rohbau EG
        addJob(
            into: context,
            event: event,
            employeeName: "Meier",
            status: .inProgress,
            storageLocation: "Baustelle EG",
            storageNote: "Palette",
            isHotDelivery: false,
            processingDetails: """
Rohbau EG – Aussenmauern + Innenwände

- Schalung pruefen
- Bewehrung nach Stahlplan
- Betonieren Decke EG
- Aushaertezeit dokumentieren
"""
        )

        // Auftrag 2: Elektro EG
        addJob(
            into: context,
            event: event,
            employeeName: "Schmidt",
            status: .pending,
            storageLocation: "Materiallager",
            storageNote: "Gitterbox",
            isHotDelivery: false,
            processingDetails: """
Elektroinstallation EG

- Schlitze nach Plan fraesen
- Leerrohre + Dosen setzen
- Kabel einziehen (NYM 3x1,5 / 5x2,5)
- Verteilung anschliessen
"""
        )

        // Auftrag 3: Sanitaer OG
        addJob(
            into: context,
            event: event,
            employeeName: "Weber",
            status: .pending,
            storageLocation: "Container",
            storageNote: "Einzelteile",
            isHotDelivery: true,
            processingDetails: """
Sanitaer OG – Baeder + Kueche

- Rohrleitungen vormontieren
- Warm-/Kaltwasser verlegen
- Abwasseranschluesse
- Druckpruefung durchfuehren
"""
        )

        do {
            try context.save()
            print("DemoSeeder: Demo-Baustelle + Auftraege angelegt.")
        } catch {
            print("DemoSeeder: Fehler beim Speichern: \(error)")
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
        job.totalProcessingTime = 0
        job.lastStartTime = nil
    }
}
