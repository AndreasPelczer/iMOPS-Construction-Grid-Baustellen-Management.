// ViewModels/EventListViewModel.swift

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

// MARK: - EventListViewModel

class EventListViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {

    // MARK: - Properties
    @Published var events: [Event] = []
    @Published var lastError: String? = nil

    private let viewContext: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<Event>!

    // MARK: - Initializer

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        super.init()
        setupFetchedResultsController()
    }

    // MARK: - Setup

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        let dateSort = NSSortDescriptor(key: "eventStartTime", ascending: true)
        request.sortDescriptors = [dateSort]

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
                self.events = self.prioritizeEvents(fetched)
            }
        } catch {
            lastError = "Laden fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Filter

    func applyFilter(filter: EventFilter) {
        applyFilterAndSearch(filter: filter, query: "")
    }

    func applyFilterAndSearch(filter: EventFilter, query: String) {
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
                self.events = self.prioritizeEvents(fetched)
            }
        } catch {
            lastError = "Suche fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Priorisierung

    private func prioritizeEvents(_ fetchedEvents: [Event]) -> [Event] {
        return fetchedEvents.sorted { (a: Event, b: Event) -> Bool in
            let activeA = hasActiveJobs(event: a)
            let activeB = hasActiveJobs(event: b)
            if activeA != activeB { return activeA }
            return (a.eventStartTime ?? Date()) < (b.eventStartTime ?? Date())
        }
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
                self.events = self.prioritizeEvents(fetched)
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
