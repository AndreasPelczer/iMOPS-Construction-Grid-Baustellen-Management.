import Foundation
import CoreData
import Observation

@Observable
final class AddJobViewModel {
    private let viewContext: NSManagedObjectContext
    let event: Event

    // MARK: - Zettelkopf
    var orderNumber: String = ""
    var station: String = ""
    var deadline: Date = Date()
    var hasDeadline: Bool = true
    var persons: Int = 0

    // MARK: - Zuweisung
    var employeeName: String = ""

    // MARK: - Status
    var jobStatus: JobStatus = .pending

    // MARK: - Auftragstext
    var taskSummary: String = ""

    // MARK: - Positionen
    var lineItems: [AuftragLineItem] = []

    // MARK: - Behälter / Lager
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

    // MARK: - Fehlerzustand
    var lastViolation: RuleViolation? = nil

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
        if case .failure = BauValidator.validateAuftrag(
            id: orderNumber.isEmpty ? "_draft" : orderNumber,
            titel: taskSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            baustelle: event.title ?? station
        ) { return true }
        return false
    }

    // MARK: - Save

    func saveNewJob() -> Bool {
        lastViolation = nil

        let validation = BauValidator.validateAuftrag(
            id: orderNumber.isEmpty ? "_draft" : orderNumber,
            titel: taskSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            baustelle: event.title ?? station
        )
        if case .failure(let violation) = validation {
            lastViolation = violation
            return false
        }

        let newJob = Auftrag(context: viewContext)
        newJob.employeeName = employeeName
        newJob.storageLocation = storageLocation
        newJob.storageNote = storageNote
        newJob.deliveryTemperature = isHotDelivery
        newJob.processingDetails = taskSummary
        newJob.status = jobStatus
        newJob.isCompleted = (jobStatus == .completed)
        newJob.event = event
        newJob.totalProcessingTime = 0.0
        newJob.lastStartTime = nil

        var extras = AuftragExtrasPayload()
        extras.trainingMode = trainingMode
        extras.orderNumber = orderNumber
        extras.station = station
        extras.persons = persons
        extras.deadline = hasDeadline ? deadline : nil
        extras.lineItems = lineItems.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let tpl = selectedTemplate {
            extras.checklist = tpl.steps.map { AuftragChecklistItem(title: $0) }
        }
        newJob.extras = extras.toJSONString()

        do {
            try viewContext.save()
            return true
        } catch {
            lastViolation = RuleViolation(
                ruleId: "BAU-R99",
                reason: "Speichern fehlgeschlagen: \(error.localizedDescription)",
                fields: nil
            )
            return false
        }
    }
}
