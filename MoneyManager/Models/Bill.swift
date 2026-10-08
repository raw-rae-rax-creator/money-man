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

    // Payment details. All optional so bills/subscriptions saved earlier still decode.
    /// Price in another currency (e.g. $9.99); `amount` is the estimate in the app currency.
    var foreignAmount: Double?
    var foreignCurrency: String?
    /// App-currency units per one foreign unit, learned from the last payment.
    var lastRate: Double?
    var lastPaidAt: Date?
    var lastPaidAmount: Double?

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
        note: String = "",
        foreignAmount: Double? = nil,
        foreignCurrency: String? = nil
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
        self.foreignAmount = foreignAmount
        self.foreignCurrency = foreignCurrency
        if let foreignAmount = foreignAmount, foreignAmount > 0 {
            self.lastRate = amount / foreignAmount
        }
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

    // Payment details. All optional so bills/subscriptions saved earlier still decode.
    /// Price in another currency (e.g. $9.99); `amount` is the estimate in the app currency.
    var foreignAmount: Double?
    var foreignCurrency: String?
    /// App-currency units per one foreign unit, learned from the last payment.
    var lastRate: Double?
    var lastPaidAt: Date?
    var lastPaidAmount: Double?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        isActive: Bool = true,
        foreignAmount: Double? = nil,
        foreignCurrency: String? = nil
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
        self.foreignAmount = foreignAmount
        self.foreignCurrency = foreignCurrency
        if let foreignAmount = foreignAmount, foreignAmount > 0 {
            self.lastRate = amount / foreignAmount
        }
    }

    var daysUntilBilling: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let billingDay = calendar.startOfDay(for: nextBillingDate)
        return calendar.dateComponents([.day], from: today, to: billingDay).day ?? 0
    }

    /// The billing date has come and the payment hasn't been recorded yet.
    var isDue: Bool {
        daysUntilBilling <= 0
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

    var title: String {
        switch self {
        case .weekly: return "Weekly".localized
        case .monthly: return "Monthly".localized
        case .quarterly: return "Quarterly".localized
        case .yearly: return "Yearly".localized
        }
    }

    var dateComponent: DateComponents {
        switch self {
        case .weekly: return DateComponents(day: 7)
        case .monthly: return DateComponents(month: 1)
        case .quarterly: return DateComponents(month: 3)
        case .yearly: return DateComponents(year: 1)
        }
    }
}

// MARK: - Payments

/// What the payment sheet needs to know about a bill or a subscription.
struct PaymentRequest: Identifiable {
    enum Source {
        case bill
        case subscription
    }

    let id: UUID
    let source: Source
    let name: String
    let dueDate: Date
    let amount: Double
    let foreignAmount: Double?
    let foreignCurrency: String?
    let lastRate: Double?
    let lastPaidAmount: Double?
    let accountId: UUID?
    let categoryId: UUID?

    init(bill: Bill) {
        id = bill.id
        source = .bill
        name = bill.name
        dueDate = bill.dueDate
        amount = bill.amount
        foreignAmount = bill.foreignAmount
        foreignCurrency = bill.foreignCurrency
        lastRate = bill.lastRate
        lastPaidAmount = bill.lastPaidAmount
        accountId = bill.accountId
        categoryId = bill.categoryId
    }

    init(subscription: Subscription) {
        id = subscription.id
        source = .subscription
        name = subscription.name
        dueDate = subscription.nextBillingDate
        amount = subscription.amount
        foreignAmount = subscription.foreignAmount
        foreignCurrency = subscription.foreignCurrency
        lastRate = subscription.lastRate
        lastPaidAmount = subscription.lastPaidAmount
        accountId = subscription.accountId
        categoryId = subscription.categoryId
    }

    /// For a foreign-currency price, the estimate at the last known rate.
    var suggestedAmount: Double {
        if let foreignAmount = foreignAmount, let lastRate = lastRate {
            return (foreignAmount * lastRate).rounded()
        }
        return amount
    }
}

struct PaymentResult {
    let amount: Double
    /// `nil` only marks the item as paid without recording an expense.
    let accountId: UUID?
    let categoryId: UUID?
    let date: Date
    /// Store the paid amount as the new default for next time.
    let rememberAmount: Bool
}
