import Foundation
import CoreData

@objc(CategoryEntity)
public class CategoryEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var color: String
    @NSManaged public var type: String
    @NSManaged public var parentId: UUID?
    @NSManaged public var budgetLimit: Double
    @NSManaged public var isActive: Bool
    @NSManaged public var sortOrder: Int16
    @NSManaged public var createdAt: Date

    func toCategory() -> Category? {
        guard let type = CategoryType(rawValue: type) else { return nil }
        return Category(
            id: id,
            name: name,
            icon: icon,
            color: color,
            type: type,
            parentId: parentId,
            budgetLimit: budgetLimit > 0 ? budgetLimit : nil,
            isActive: isActive,
            sortOrder: Int(sortOrder),
            createdAt: createdAt
        )
    }
}

extension CategoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryEntity> {
        return NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
    }
}
