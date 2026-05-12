import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - EventFilter

enum EventFilter: String, CaseIterable, Identifiable {
    case upcoming = "Aktiv"
    case past = "Abgeschlossen"
    case all = "Alle"
    var id: String { self.rawValue }
}

// MARK: - EventSortOrder

enum EventSortOrder: String, CaseIterable, Identifiable {
    case datumNeuAlt   = "Datum (neu → alt)"
    case datumAltNeu   = "Datum (alt → neu)"
    case nameAZ        = "Name (A → Z)"
    case offeneMaengel = "Offene Mängel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .datumNeuAlt:   return "arrow.down.calendar"
        case .datumAltNeu:   return "arrow.up.calendar"
        case .nameAZ:        return "textformat.abc"
        case .offeneMaengel: return "exclamationmark.triangle"
        }
    }
}

// MARK: - EventListViewModel

class EventListViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {

    @Published var events: [Event] = []
    @Published var lastError: String? = nil

    private(set) var currentSortOrder: EventSortOrder = .datumNeuAlt
    private var currentFilter: EventFilter = .upcoming
    private var currentQuery: String = ""

    private let viewContext: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<Event>!

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        super.init()
        setupFetchedResultsController()
    }

    // MARK: - Setup

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "eventStartTime", ascending: true)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
            if let fetched = fetchedResultsController.fetchedObjects {
                self.events = self.sortEvents(fetched, sort: currentSortOrder)
            }
        } catch {
            lastError = "Laden fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Filter + Suche + Sortierung

    func applyFilter(filter: EventFilter) {
        applyFilterAndSearch(filter: filter, query: "", sort: currentSortOrder)
    }

    func applyFilterAndSearch(filter: EventFilter, query: String, sort: EventSortOrder) {
        currentFilter    = filter
        currentQuery     = query
        currentSortOrder = sort

        let now = Date()
        var predicates: [NSPredicate] = []

        switch filter {
        case .upcoming:
            predicates.append(NSPredicate(format: "eventEndTime == nil OR eventEndTime >= %@", now as NSDate))
        case .past:
            predicates.append(NSPredicate(format: "eventEndTime < %@", now as NSDate))
        case .all:
            break
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            predicates.append(NSPredicate(
                format: "title CONTAINS[cd] %@ OR location CONTAINS[cd] %@ OR bauherr CONTAINS[cd] %@ OR eventNumber CONTAINS[cd] %@",
                q, q, q, q))
        }

        fetchedResultsController.fetchRequest.predicate = predicates.isEmpty
            ? nil
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            try fetchedResultsController.performFetch()
            if let fetched = fetchedResultsController.fetchedObjects {
                self.events = self.sortEvents(fetched, sort: sort)
            }
        } catch {
            lastError = "Suche fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Sortierung (in-memory)

    private func sortEvents(_ input: [Event], sort: EventSortOrder) -> [Event] {
        switch sort {
        case .datumNeuAlt:
            return input.sorted {
                ($0.eventStartTime ?? .distantPast) > ($1.eventStartTime ?? .distantPast)
            }
        case .datumAltNeu:
            return input.sorted {
                ($0.eventStartTime ?? .distantFuture) < ($1.eventStartTime ?? .distantFuture)
            }
        case .nameAZ:
            return input.sorted {
                ($0.title ?? "") < ($1.title ?? "")
            }
        case .offeneMaengel:
            return input.sorted {
                offeneMaengelCount($0) > offeneMaengelCount($1)
            }
        }
    }

    private func offeneMaengelCount(_ event: Event) -> Int {
        (event.maengel?.allObjects as? [Mangel] ?? [])
            .filter { $0.status != .behoben && $0.status != .abgenommen }.count
    }

    func hasActiveJobs(event: Event) -> Bool {
        guard let jobs = event.jobs as? Set<Auftrag> else { return false }
        return jobs.contains { $0.status == .inProgress || $0.status == .pending || $0.status == .onHold }
    }

    // MARK: - CRUD

    func deleteEvents(offsets: IndexSet) {
        withAnimation {
            offsets.map { events[$0] }.forEach { viewContext.delete($0) }
            saveContext()
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let fetched = controller.fetchedObjects as? [Event] {
            DispatchQueue.main.async {
                self.events = self.sortEvents(fetched, sort: self.currentSortOrder)
            }
        }
    }

    // MARK: - CoreData

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            lastError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
