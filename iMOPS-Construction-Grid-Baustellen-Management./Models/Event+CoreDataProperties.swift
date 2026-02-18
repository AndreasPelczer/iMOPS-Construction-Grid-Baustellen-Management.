//
//  Event+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//
//

import Foundation
import CoreData

// FÜGEN SIE DIESE KLASSENDEFINITION HINZU
@objc(Event) // Dies ist wichtig für Core Data
public class Event: NSManagedObject {
    // KEIN INHALT HIER, Properties kommen automatisch
}

extension Event {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var eventEndTime: Date?
    @NSManaged public var eventNumber: String?
    @NSManaged public var eventStartTime: Date?
    @NSManaged public var extras: String?
    @NSManaged public var location: String?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var setupTime: Date?
    @NSManaged public var startTime: Date?
    @NSManaged public var timeStamp: Date?
    @NSManaged public var title: String?
    @NSManaged public var jobs: NSSet?

}

// MARK: Generated accessors for jobs
extension Event {

    @objc(addJobsObject:)
    @NSManaged public func addToJobs(_ value: Auftrag)

    @objc(removeJobsObject:)
    @NSManaged public func removeFromJobs(_ value: Auftrag)

    @objc(addJobs:)
    @NSManaged public func addToJobs(_ values: NSSet)

    @objc(removeJobs:)
    @NSManaged public func removeFromJobs(_ values: NSSet)

}

extension Event : Identifiable {

}
