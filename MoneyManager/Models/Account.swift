import Foundation

enum AccountType: String, Codable, CaseIterable {
    case cash = "cash"
    case bank = "bank"
    case creditCard = "credit_card"
    case savings = "savings"
    case investment = "investment"
    case other = "other"
}

struct Account: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String
    var icon: String
    var color: String
    var isActive: Bool
    var includeInTotal: Bool
    var createdAt: Date

    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Double = 0.0,
        currency: String = "USD",
        icon: String = "creditcard.fill",
        color: String = "#3498DB",
        isActive: Bool = true,
        includeInTotal: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.currency = currency
        self.icon = icon
        self.color = color
        self.isActive = isActive
        self.includeInTotal = includeInTotal
        self.createdAt = Date()
    }
}
