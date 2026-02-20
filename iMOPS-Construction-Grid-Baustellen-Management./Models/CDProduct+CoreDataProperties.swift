//
//  CDProduct+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//

import Foundation
internal import CoreData


extension CDProduct {

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDProduct> {
        return NSFetchRequest<CDProduct>(entityName: "CDProduct")
    }

    @NSManaged var algorithmusText: String?
    @NSManaged var allergene: String?
    @NSManaged var beschreibung: String?
    @NSManaged var category: String?
    @NSManaged var dataSource: String?
    @NSManaged var fett: String?
    @NSManaged var id: String?
    @NSManaged var kcal: String?
    @NSManaged var name: String?
    @NSManaged var portionen: String?
    @NSManaged var stockQuantity: Double
    @NSManaged var stockUnit: String?
    @NSManaged var zucker: String?
    @NSManaged var zusatzstoffe: String?
    @NSManaged var ingredients: NSSet?

}

extension CDProduct : Identifiable {

}
