//
//  Event+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//
//

import Foundation
internal import CoreData

// FÜGEN SIE DIESE KLASSENDEFINITION HINZU
@objc(Event) // Dies ist wichtig für Core Data
class Event: NSManagedObject {
    // KEIN INHALT HIER, Properties kommen automatisch
}

extension Event {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged var eventEndTime: Date?
    @NSManaged var eventNumber: String?
    @NSManaged var eventStartTime: Date?
    @NSManaged var extras: String?
    @NSManaged var location: String?
    @NSManaged var name: String?
    @NSManaged var notes: String?
    @NSManaged var setupTime: Date?
    @NSManaged var startTime: Date?
    @NSManaged var timeStamp: Date?
    @NSManaged var title: String?
    @NSManaged var jobs: NSSet?

}

// MARK: Generated accessors for jobs
extension Event {

    @objc(addJobsObject:)
    @NSManaged func addToJobs(_ value: Auftrag)

    @objc(removeJobsObject:)
    @NSManaged func removeFromJobs(_ value: Auftrag)

    @objc(addJobs:)
    @NSManaged func addToJobs(_ values: NSSet)

    @objc(removeJobs:)
    @NSManaged func removeFromJobs(_ values: NSSet)

}

extension Event : Identifiable {

}
