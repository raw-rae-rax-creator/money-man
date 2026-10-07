import Foundation
import CoreData

@objc(AccountEntity)
public class AccountEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var balance: Double
    @NSManaged public var currency: String
    @NSManaged public var icon: String
    @NSManaged public var color: String
    @NSManaged public var isActive: Bool
    @NSManaged public var includeInTotal: Bool
    @NSManaged public var createdAt: Date

    func toAccount() -> Account? {
        guard let type = AccountType(rawValue: type) else { return nil }
        return Account(
            id: id,
            name: name,
            type: type,
            balance: balance,
            currency: currency,
            icon: icon,
            color: color,
            isActive: isActive,
            includeInTotal: includeInTotal
        )
    }
}

extension AccountEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AccountEntity> {
        return NSFetchRequest<AccountEntity>(entityName: "AccountEntity")
    }
}
