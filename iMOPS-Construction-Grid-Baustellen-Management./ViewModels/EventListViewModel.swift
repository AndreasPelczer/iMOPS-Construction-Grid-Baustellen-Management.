// ViewModels/EventListViewModel.swift

import Foundation
import CoreData
import SwiftUI

// MARK: - EventFilter ENUM (Muss außerhalb oder vor der Klasse stehen)

enum EventFilter: String, CaseIterable, Identifiable {
    case upcoming = "Bevorstehend"
    case past = "Vergangen"
    case all = "Alle"
    
    var id: String { self.rawValue }
}

// MARK: - EventListViewModel CLASS

class EventListViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {

    // MARK: - Properties
    @Published var events: [Event] = []
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
        // HINWEIS: request muss innerhalb der Funktion definiert werden
        let request: NSFetchRequest<Event> = Event.fetchRequest() 

        // KORRIGIERT: Nur EINE Definition des Sortier-Descriptors, String-basiert für Stabilität
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
            if let fetchedEvents = fetchedResultsController.fetchedObjects {
                self.events = self.prioritizeEvents(fetchedEvents)
            }
        } catch {
            print("❌ Fehler beim initialen Fetch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Filter Logik (HINWEIS: Jetzt KORREKT innerhalb der Klasse!)

    func applyFilter(filter: EventFilter) {
        let now = Date()
        var predicate: NSPredicate? = NSPredicate(format: "eventNumber != nil")
        
        switch filter {
        case .upcoming:
            let upcomingPredicate = NSPredicate(format: "eventStartTime >= %@", now as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate!, upcomingPredicate])
        case .past:
            let pastPredicate = NSPredicate(format: "eventStartTime < %@", now as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate!, pastPredicate])
        case .all:
            predicate = NSPredicate(format: "eventNumber != nil")
        }
        
        fetchedResultsController.fetchRequest.predicate = predicate
        
        do {
            try fetchedResultsController.performFetch()
            if let fetchedEvents = fetchedResultsController.fetchedObjects {
                self.events = self.prioritizeEvents(fetchedEvents)
            }
        } catch {
            print("❌ Fehler beim Filter-Fetch: \(error.localizedDescription)")
        }
    }


    // MARK: - Priorisierungslogik

    private func prioritizeEvents(_ fetchedEvents: [Event]) -> [Event] {
        return fetchedEvents.sorted { (eventA: Event, eventB: Event) -> Bool in
            let isActiveA = hasActiveJobs(event: eventA)
            let isActiveB = hasActiveJobs(event: eventB)

            if isActiveA != isActiveB {
                return isActiveA
            }
            return (eventA.eventStartTime ?? Date()) < (eventB.eventStartTime ?? Date())
        }
    }

    func hasActiveJobs(event: Event) -> Bool {
        guard let jobs = event.jobs as? Set<Auftrag> else { return false }
        return jobs.contains { job in
            // HINWEIS: job.status muss ein String-Enum oder eine Comparable Property sein
            return job.status == .inProgress || job.status == .pending || job.status == .onHold
        }
    }

    // MARK: - Öffentliche CRUD Funktionen

    func deleteEvents(offsets: IndexSet) {
        withAnimation {
            offsets.map { events[$0] }.forEach { viewContext.delete($0) }
            saveContext()
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let fetchedEvents = controller.fetchedObjects as? [Event] {
            DispatchQueue.main.async {
                self.events = self.prioritizeEvents(fetchedEvents)
            }
        }
    }

    // MARK: - Core Data Helper

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("❌ Fehler beim Speichern im EventListViewModel: \(nsError.localizedDescription)")
        }
    }
}
