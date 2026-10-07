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
        reminderDaysBefore: Int = 3
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
