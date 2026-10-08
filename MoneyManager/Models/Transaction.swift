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
    // Where the transaction was added (only when the location setting is on).
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    /// Set when the transaction was cancelled instead of deleted. A cancelled transaction
    /// stays in the list but no longer affects account balances or statistics.
    var cancelledAt: Date?

    var isCancelled: Bool {
        cancelledAt != nil
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

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
        tags: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        cancelledAt: Date? = nil
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
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.cancelledAt = cancelledAt
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

    var title: String {
        switch self {
        case .daily: return "Daily".localized
        case .weekly: return "Weekly".localized
        case .biweekly: return "Every 2 weeks".localized
        case .monthly: return "Monthly".localized
        case .yearly: return "Yearly".localized
        }
    }

    var dateComponent: DateComponents {
        switch self {
        case .daily: return DateComponents(day: 1)
        case .weekly: return DateComponents(day: 7)
        case .biweekly: return DateComponents(day: 14)
        case .monthly: return DateComponents(month: 1)
        case .yearly: return DateComponents(year: 1)
        }
    }
}
