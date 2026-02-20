//
//  CDIngredient+CoreDataProperties.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//

import Foundation
internal import CoreData


extension CDIngredient {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDIngredient> {
        return NSFetchRequest<CDIngredient>(entityName: "CDIngredient")
    }

    @NSManaged public var einheit: String?
    @NSManaged public var menge: String?
    @NSManaged public var name: String?
    @NSManaged public var product: CDProduct?

}

extension CDIngredient : Identifiable {

}
