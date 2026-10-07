import Foundation
import CoreData

@objc(BudgetEntity)
public class BudgetEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var categoryId: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var period: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date

    func toBudget() -> Budget? {
        guard let period = BudgetPeriod(rawValue: period) else { return nil }
        return Budget(
            id: id,
            categoryId: categoryId,
            amount: amount,
            period: period,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive
        )
    }
}

extension BudgetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BudgetEntity> {
        return NSFetchRequest<BudgetEntity>(entityName: "BudgetEntity")
    }
}
