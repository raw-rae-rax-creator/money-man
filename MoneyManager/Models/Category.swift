import Foundation

enum CategoryType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case both = "both"
}

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    var type: CategoryType
    var parentId: UUID?
    var budgetLimit: Double?
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date

    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        type: CategoryType,
        parentId: UUID? = nil,
        budgetLimit: Double? = nil,
        isActive: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.parentId = parentId
        self.budgetLimit = budgetLimit
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

extension Category {
    static let defaultExpenseCategories: [Category] = [
        Category(name: "Food & Dining", icon: "fork.knife", color: "#FF6B6B", type: .expense, sortOrder: 1),
        Category(name: "Transportation", icon: "car.fill", color: "#4ECDC4", type: .expense, sortOrder: 2),
        Category(name: "Shopping", icon: "bag.fill", color: "#45B7D1", type: .expense, sortOrder: 3),
        Category(name: "Entertainment", icon: "gamecontroller.fill", color: "#96CEB4", type: .expense, sortOrder: 4),
        Category(name: "Bills & Utilities", icon: "doc.text.fill", color: "#FFEAA7", type: .expense, sortOrder: 5),
        Category(name: "Healthcare", icon: "heart.fill", color: "#DDA0DD", type: .expense, sortOrder: 6),
        Category(name: "Education", icon: "book.fill", color: "#98D8C8", type: .expense, sortOrder: 7),
        Category(name: "Travel", icon: "airplane", color: "#F7DC6F", type: .expense, sortOrder: 8),
        Category(name: "Other", icon: "ellipsis.circle", color: "#95A5A6", type: .expense, sortOrder: 99)
    ]

    static let defaultIncomeCategories: [Category] = [
        Category(name: "Salary", icon: "dollarsign.circle.fill", color: "#2ECC71", type: .income, sortOrder: 1),
        Category(name: "Business", icon: "briefcase.fill", color: "#3498DB", type: .income, sortOrder: 2),
        Category(name: "Investments", icon: "chart.line.uptrend.xyaxis", color: "#9B59B6", type: .income, sortOrder: 3),
        Category(name: "Gifts", icon: "gift.fill", color: "#E74C3C", type: .income, sortOrder: 4),
        Category(name: "Other Income", icon: "plus.circle.fill", color: "#1ABC9C", type: .income, sortOrder: 99)
    ]
}
