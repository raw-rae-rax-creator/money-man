import Foundation

struct Bill: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var dueDate: Date
    var recurringFrequency: RecurringFrequency?
    var categoryId: UUID?
    var accountId: UUID?
    var isPaid: Bool
    var isRecurring: Bool
    var reminderDaysBefore: Int
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        dueDate: Date,
        recurringFrequency: RecurringFrequency? = nil,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        isPaid: Bool = false,
        isRecurring: Bool = false,
        reminderDaysBefore: Int = 3,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.recurringFrequency = recurringFrequency
        self.categoryId = categoryId
        self.accountId = accountId
        self.isPaid = isPaid
        self.isRecurring = isRecurring
        self.reminderDaysBefore = reminderDaysBefore
        self.note = note
        self.createdAt = Date()
    }

    var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: today, to: dueDay)
        return components.day ?? 0
    }

    var isOverdue: Bool {
        return daysUntilDue < 0 && !isPaid
    }

    var isDueSoon: Bool {
        let days = daysUntilDue
        return days >= 0 && days <= reminderDaysBefore && !isPaid
    }
}

struct Subscription: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var billingCycle: BillingCycle
    var nextBillingDate: Date
    var categoryId: UUID?
    var accountId: UUID?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.categoryId = categoryId
        self.accountId = accountId
        self.isActive = isActive
        self.createdAt = Date()
    }

    var monthlyCost: Double {
        switch billingCycle {
        case .monthly:
            return amount
        case .yearly:
            return amount / 12
        case .weekly:
            return amount * 52 / 12
        case .quarterly:
            return amount / 3
        }
    }

    var yearlyCost: Double {
        return monthlyCost * 12
    }
}

enum BillingCycle: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var dateComponent: DateComponents {
        switch self {
        case .weekly: return DateComponents(day: 7)
        case .monthly: return DateComponents(month: 1)
        case .quarterly: return DateComponents(month: 3)
        case .yearly: return DateComponents(year: 1)
        }
    }
}
