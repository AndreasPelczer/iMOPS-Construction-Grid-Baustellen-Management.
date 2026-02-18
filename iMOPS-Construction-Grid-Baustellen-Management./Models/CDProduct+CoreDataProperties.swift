//
//  CDProduct+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//

import Foundation
import CoreData


extension CDProduct {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDProduct> {
        return NSFetchRequest<CDProduct>(entityName: "CDProduct")
    }

    @NSManaged public var algorithmusText: String?
    @NSManaged public var allergene: String?
    @NSManaged public var beschreibung: String?
    @NSManaged public var category: String?
    @NSManaged public var dataSource: String?
    @NSManaged public var fett: String?
    @NSManaged public var id: String?
    @NSManaged public var kcal: String?
    @NSManaged public var name: String?
    @NSManaged public var portionen: String?
    @NSManaged public var stockQuantity: Double
    @NSManaged public var stockUnit: String?
    @NSManaged public var zucker: String?
    @NSManaged public var zusatzstoffe: String?
    @NSManaged public var ingredients: NSSet?

}

extension CDProduct : Identifiable {

}
