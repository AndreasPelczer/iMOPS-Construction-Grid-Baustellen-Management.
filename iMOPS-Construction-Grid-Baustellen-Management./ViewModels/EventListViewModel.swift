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
        let now = Date()
        let predicate: NSPredicate?

        switch filter {
        case .upcoming:
            predicate = NSPredicate(format: "eventEndTime == nil OR eventEndTime >= %@", now as NSDate)
        case .past:
            predicate = NSPredicate(format: "eventEndTime < %@", now as NSDate)
        case .all:
            predicate = nil
        }

        fetchedResultsController.fetchRequest.predicate = predicate

        do {
            try fetchedResultsController.performFetch()
            if let fetched = fetchedResultsController.fetchedObjects {
                self.events = self.prioritizeEvents(fetched)
            }
        } catch {
            lastError = "Filter fehlgeschlagen: \(error.localizedDescription)"
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
