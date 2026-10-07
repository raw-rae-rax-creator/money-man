import Foundation

struct SavingsGoal: Identifiable, Codable {
    let id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var icon: String
    var color: String
    var isActive: Bool
    var createdAt: Date
    var transactions: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        deadline: Date? = nil,
        icon: String = "target",
        color: String = "#3498DB",
        isActive: Bool = true,
        transactions: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.icon = icon
        self.color = color
        self.isActive = isActive
        self.transactions = transactions
        self.createdAt = Date()
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return (currentAmount / targetAmount) * 100
    }

    var remaining: Double {
        return targetAmount - currentAmount
    }

    var isCompleted: Bool {
        return currentAmount >= targetAmount
    }
}
