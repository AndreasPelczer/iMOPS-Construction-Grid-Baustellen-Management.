//
//  Auftrag+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//
//

import Foundation
internal import CoreData


extension Auftrag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Auftrag> {
        return NSFetchRequest<Auftrag>(entityName: "Auftrag")
    }

    @NSManaged public var deliveryTemperature: Bool
    @NSManaged public var employeeName: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var lastStartTime: Date?
    @NSManaged public var processingDetails: String?
    @NSManaged public var statusRawValue: String?
    @NSManaged public var storageLocation: String?
    @NSManaged public var storageNote: String?
    @NSManaged public var totalProcessingTime: Double
    @NSManaged public var event: Event?
    @NSManaged public var extras: String?


}

extension Auftrag : Identifiable {

}
