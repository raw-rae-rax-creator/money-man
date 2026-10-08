import Foundation

enum DebtType: String, Codable, CaseIterable {
    case given = "given"      // Я дал в долг
    case received = "received" // Я взял в долг
}

enum DebtStatus: String, Codable, CaseIterable {
    case active = "active"
    case returned = "returned"
    case overdue = "overdue"
}

/// Частичный возврат долга
struct DebtRepayment: Identifiable, Codable, Hashable {
    let id: UUID
    var amount: Double
    var date: Date
    var note: String
    /// Account the returned money went to / came from; `nil` leaves balances untouched.
    var accountId: UUID?

    init(id: UUID = UUID(), amount: Double, date: Date = Date(), note: String = "", accountId: UUID? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.accountId = accountId
    }
}

/// Долги хранятся отдельно от транзакций: они двигают деньги на счетах (если выбран счёт),
/// но не попадают в статистику доходов и расходов.
struct Debt: Identifiable, Codable {
    let id: UUID
    var personName: String
    var amount: Double
    var type: DebtType
    var dateGiven: Date
    var expectedReturnDate: Date?
    var actualReturnDate: Date?
    var status: DebtStatus
    var note: String
    var categoryId: UUID?
    var accountId: UUID?
    var reminderEnabled: Bool
    var reminderDaysBefore: Int
    var createdAt: Date
    var repayments: [DebtRepayment]

    enum CodingKeys: String, CodingKey {
        case id, personName, amount, type, dateGiven, expectedReturnDate, actualReturnDate
        case status, note, categoryId, accountId, reminderEnabled, reminderDaysBefore, createdAt
        case repayments
    }

    init(
        id: UUID = UUID(),
        personName: String,
        amount: Double,
        type: DebtType,
        dateGiven: Date = Date(),
        expectedReturnDate: Date? = nil,
        actualReturnDate: Date? = nil,
        status: DebtStatus = .active,
        note: String = "",
        categoryId: UUID? = nil,
        accountId: UUID? = nil,
        reminderEnabled: Bool = false,
        reminderDaysBefore: Int = 3,
        repayments: [DebtRepayment] = []
    ) {
        self.id = id
        self.personName = personName
        self.amount = amount
        self.type = type
        self.dateGiven = dateGiven
        self.expectedReturnDate = expectedReturnDate
        self.actualReturnDate = actualReturnDate
        self.status = status
        self.note = note
        self.categoryId = categoryId
        self.accountId = accountId
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.createdAt = Date()
        self.repayments = repayments
    }

    // Debts saved before repayments existed have no "repayments" key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        personName = try container.decode(String.self, forKey: .personName)
        amount = try container.decode(Double.self, forKey: .amount)
        type = try container.decode(DebtType.self, forKey: .type)
        dateGiven = try container.decode(Date.self, forKey: .dateGiven)
        expectedReturnDate = try container.decodeIfPresent(Date.self, forKey: .expectedReturnDate)
        actualReturnDate = try container.decodeIfPresent(Date.self, forKey: .actualReturnDate)
        status = try container.decode(DebtStatus.self, forKey: .status)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        accountId = try container.decodeIfPresent(UUID.self, forKey: .accountId)
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderDaysBefore = try container.decodeIfPresent(Int.self, forKey: .reminderDaysBefore) ?? 3
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? dateGiven
        repayments = try container.decodeIfPresent([DebtRepayment].self, forKey: .repayments) ?? []
    }

    var repaidAmount: Double {
        repayments.reduce(0) { $0 + $1.amount }
    }

    /// Сколько ещё осталось вернуть
    var remainingAmount: Double {
        status == .returned ? 0 : max(amount - repaidAmount, 0)
    }

    var repaidFraction: Double {
        guard amount > 0 else { return 0 }
        return status == .returned ? 1 : min(repaidAmount / amount, 1)
    }

    var daysUntilDue: Int? {
        guard let expectedReturnDate = expectedReturnDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: expectedReturnDate)
        let components = calendar.dateComponents([.day], from: today, to: dueDay)
        return components.day
    }

    var isOverdue: Bool {
        guard let days = daysUntilDue else { return false }
        return days < 0 && status == .active
    }

    var isDueSoon: Bool {
        guard let days = daysUntilDue else { return false }
        return days >= 0 && days <= reminderDaysBefore && status == .active
    }

    var daysActive: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: dateGiven)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: startDay, to: today)
        return components.day ?? 0
    }
}
