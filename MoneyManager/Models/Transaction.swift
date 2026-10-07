import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var type: TransactionType
    var categoryId: UUID
    var accountId: UUID
    var note: String
    var date: Date
    var isRecurring: Bool
    var recurringFrequency: RecurringFrequency?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        amount: Double,
        type: TransactionType,
        categoryId: UUID,
        accountId: UUID,
        note: String = "",
        date: Date = Date(),
        isRecurring: Bool = false,
        recurringFrequency: RecurringFrequency? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.accountId = accountId
        self.note = note
        self.date = date
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case yearly = "yearly"
}
