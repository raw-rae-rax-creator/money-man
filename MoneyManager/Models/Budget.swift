import Foundation

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}

struct Budget: Identifiable, Codable {
    let id: UUID
    var categoryId: UUID?
    var amount: Double
    var period: BudgetPeriod
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        categoryId: UUID? = nil,
        amount: Double,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.categoryId = categoryId
        self.amount = amount
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = Date()
    }
}

struct BudgetSummary: Identifiable {
    let category: Category?
    let budget: Budget
    let spent: Double
    let remaining: Double
    let percentage: Double

    var id: UUID { budget.id }
}
