import Foundation
import CoreData

@objc(Employee)
class Employee: NSManagedObject {}

extension Employee {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Employee> {
        return NSFetchRequest<Employee>(entityName: "Employee")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var rolle: String?
    @NSManaged var telefon: String?
    @NSManaged var notiz: String?
    @NSManaged var isActive: Bool
}

extension Employee: Identifiable {}
