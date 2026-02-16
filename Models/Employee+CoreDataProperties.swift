import Foundation
import CoreData

@objc(Employee)
public class Employee: NSManagedObject {}

extension Employee {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Employee> {
        return NSFetchRequest<Employee>(entityName: "Employee")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var rolle: String?
    @NSManaged public var telefon: String?
    @NSManaged public var notiz: String?
    @NSManaged public var isActive: Bool
}

extension Employee: Identifiable {}
