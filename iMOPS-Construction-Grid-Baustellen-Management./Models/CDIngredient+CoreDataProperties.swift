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

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDIngredient> {
        return NSFetchRequest<CDIngredient>(entityName: "CDIngredient")
    }

    @NSManaged var einheit: String?
    @NSManaged var menge: String?
    @NSManaged var name: String?
    @NSManaged var product: CDProduct?

}

extension CDIngredient : Identifiable {

}
