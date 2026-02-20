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

    @nonobjc class func fetchRequest() -> NSFetchRequest<Auftrag> {
        return NSFetchRequest<Auftrag>(entityName: "Auftrag")
    }

    @NSManaged var deliveryTemperature: Bool
    @NSManaged var employeeName: String?
    @NSManaged var isCompleted: Bool
    @NSManaged var lastStartTime: Date?
    @NSManaged var processingDetails: String?
    @NSManaged var statusRawValue: String?
    @NSManaged var storageLocation: String?
    @NSManaged var storageNote: String?
    @NSManaged var totalProcessingTime: Double
    @NSManaged var event: Event?
    @NSManaged var extras: String?


}

extension Auftrag : Identifiable {

}
