import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - EventFilter

enum EventFilter: String, CaseIterable, Identifiable {
    /// 🔴 Bis 21.09.2026 hiessen die Reiter "Aktiv / Abgeschlossen / Alle" und rechneten
    /// nur mit dem KALENDER: Endtermin vorbei = abgeschlossen, auch wenn kein Handschlag
    /// getan war. Eine Baustelle, die noch geplant wird, war nicht von einer zu
    /// unterscheiden, auf der gearbeitet wird.
    ///
    /// Jetzt fragen die Reiter die ARBEIT — mit derselben Rechnung und denselben
    /// Wörtern wie der Tagesblick (`Tagesblick.Phase`). EINE Wahrheit, EINE Sprache.
    case planung = "In Planung"
    case laeuft  = "Läuft"
    case fertig  = "Fertig"
    case alle    = "Alle"

    var id: String { self.rawValue }

    /// Die Phase, die dieser Reiter zeigt — nil heisst: alles durchlassen.
    var phase: Tagesblick.Phase? {
        switch self {
        case .planung: return .planung
        case .laeuft:  return .laeuft
        case .fertig:  return .fertig
        case .alle:    return nil
        }
    }
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
    private var currentFilter: EventFilter = .alle
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

        var predicates: [NSPredicate] = []

        // Über die Phase wird NACH dem Holen gefiltert: sie steckt in den Aufträgen,
        // nicht in einem Feld — dafür gibt es kein sauberes Core-Data-Prädikat.

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
                let gefiltert = filter.phase.map { gesucht in
                    fetched.filter { Tagesblick.Phase.von($0) == gesucht }
                } ?? fetched
                self.events = self.sortEvents(gefiltert, sort: sort)
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
