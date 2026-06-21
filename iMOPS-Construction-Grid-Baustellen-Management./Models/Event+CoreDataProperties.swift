//
//  Event+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//

import Foundation
import CoreData

@objc(Event)
class Event: NSManagedObject {
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
    @NSManaged var bauherr: String?
    @NSManaged var architekt: String?
    @NSManaged var baugenehmigungNr: String?
    @NSManaged var jobs: NSSet?
    @NSManaged var maengel: NSSet?
    @NSManaged var lvPositionen: NSSet?

}

// MARK: Generated accessors for maengel
extension Event {

    @objc(addMaengelObject:)
    @NSManaged func addToMaengel(_ value: Mangel)

    @objc(removeMaengelObject:)
    @NSManaged func removeFromMaengel(_ value: Mangel)

    @objc(addMaengel:)
    @NSManaged func addToMaengel(_ values: NSSet)

    @objc(removeMaengel:)
    @NSManaged func removeFromMaengel(_ values: NSSet)

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

// MARK: Generated accessors for lvPositionen
extension Event {

    @objc(addLvPositionenObject:)
    @NSManaged func addToLvPositionen(_ value: LVPosition)

    @objc(removeLvPositionenObject:)
    @NSManaged func removeFromLvPositionen(_ value: LVPosition)

    @objc(addLvPositionen:)
    @NSManaged func addToLvPositionen(_ values: NSSet)

    @objc(removeLvPositionen:)
    @NSManaged func removeFromLvPositionen(_ values: NSSet)

}

extension Event: Identifiable {}
