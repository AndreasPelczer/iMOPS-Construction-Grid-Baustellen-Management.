import Foundation
internal import CoreData
import Observation

@Observable
final class AddJobViewModel {
    private let viewContext: NSManagedObjectContext
    let event: Event

    // MARK: - Zettelkopf (oben am Papier)
    var orderNumber: String = ""        // 9779-04
    var station: String = ""            // Torhaus E2
    var deadline: Date = Date()         // Uhrzeit
    var hasDeadline: Bool = true
    var persons: Int = 0                // Personen/Portionen

    // MARK: - Zuweisung (optional)
    var employeeName: String = ""

    // MARK: - Status
    var jobStatus: JobStatus = .pending

    // MARK: - „Zettel-Body"
    // Kurzer Auftragstext (das, was du aktuell als processingDetails nutzt)
    var taskSummary: String = ""        // z.B. "Bulgur 6x Rezept, 10:30 schicken"

    // Produktionspositionen (wie auf dem Zettel)
    var lineItems: [AuftragLineItem] = []

    // MARK: - Behälter / Lager (deine existierenden Felder)
    var storageLocation: String
    var storageNote: String
    var isHotDelivery: Bool = false

    let storageLocations = [
        "Baustelle EG", "Baustelle OG", "Materiallager",
        "Container", "Werkstatt", "Bauhof"
    ]
    let storageNotes = [
        "Palette", "Gitterbox", "Sack/Gebinde",
        "Einzelteile", "Europalette", "Big Bag"
    ]

    // MARK: - SOP Template
    var trainingMode: Bool = false
    var selectedTemplate: AuftragTemplate? = nil

    init(event: Event, context: NSManagedObjectContext) {
        self.event = event
        self.viewContext = context

        self.storageLocation = storageLocations.first ?? ""
        self.storageNote = storageNotes.first ?? ""
    }

    // MARK: - Helpers
    func addLineItem() {
        lineItems.append(AuftragLineItem(title: ""))
    }

    func removeLineItem(_ item: AuftragLineItem) {
        lineItems.removeAll { $0.id == item.id }
    }

    var isSaveButtonDisabled: Bool {
        // Minimal: ohne "Was ist zu tun?" speichern wir keinen Auftrag
        taskSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Save
    func saveNewJob() -> Bool {
        let newJob = Auftrag(context: viewContext)

        // CoreData-Felder, die es bei dir gibt:
        newJob.employeeName = employeeName
        newJob.storageLocation = storageLocation
        newJob.storageNote = storageNote
        newJob.deliveryTemperature = isHotDelivery

        // "Was ist zu tun?" → in processingDetails (damit Row/Listen was zeigen)
        newJob.processingDetails = taskSummary

        newJob.status = jobStatus
        newJob.isCompleted = (jobStatus == .completed)
        newJob.event = event

        newJob.totalProcessingTime = 0.0
        newJob.lastStartTime = nil

        // Extras (Zettelkopf + Positionen + SOP)
        var extras = AuftragExtrasPayload()
        extras.trainingMode = trainingMode
        extras.orderNumber = orderNumber
        extras.station = station
        extras.persons = persons
        extras.deadline = hasDeadline ? deadline : nil

        // Positionen: leere Titel rausfiltern
        extras.lineItems = lineItems.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // SOP aus Template (optional)
        if let tpl = selectedTemplate {
            extras.checklist = tpl.steps.map { AuftragChecklistItem(title: $0) }
        }

        newJob.extras = extras.toJSONString()

        do {
            try viewContext.save()
            return true
        } catch {
            print("Fehler beim Speichern des neuen Auftrags: \(error)")
            return false
        }
    }
}
