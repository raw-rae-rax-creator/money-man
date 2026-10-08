import Foundation
import CoreData

@objc(TransactionEntity)
public class TransactionEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var amount: Double
    @NSManaged public var type: String
    @NSManaged public var categoryId: UUID
    @NSManaged public var accountId: UUID
    @NSManaged public var note: String
    @NSManaged public var date: Date
    @NSManaged public var isRecurring: Bool
    @NSManaged public var recurringFrequency: String?
    @NSManaged public var tags: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var placeName: String?

    func toTransaction() -> Transaction? {
        guard let type = TransactionType(rawValue: type) else { return nil }
        let frequency = recurringFrequency.flatMap { RecurringFrequency(rawValue: $0) }
        let tagsArray = tags.isEmpty ? [] : tags.components(separatedBy: ",")

        return Transaction(
            id: id,
            amount: amount,
            type: type,
            categoryId: categoryId,
            accountId: accountId,
            note: note,
            date: date,
            isRecurring: isRecurring,
            recurringFrequency: frequency,
            tags: tagsArray,
            latitude: latitude?.doubleValue,
            longitude: longitude?.doubleValue,
            placeName: placeName
        )
    }
}

extension TransactionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionEntity> {
        return NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
    }
}
