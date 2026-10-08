import Foundation
import SwiftUI

@MainActor
class DebtsViewModel: ObservableObject {
    @Published var debts: [Debt] = []
    @Published var isLoading: Bool = false
    @Published var showAddSheet: Bool = false
    @Published var editingDebt: Debt?

    @Published var personName: String = ""
    @Published var amount: String = ""
    @Published var debtType: DebtType = .given
    @Published var dateGiven: Date = Date()
    @Published var expectedReturnDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @Published var hasExpectedReturnDate: Bool = true
    @Published var note: String = ""
    @Published var reminderEnabled: Bool = false
    @Published var reminderDaysBefore: Int = 3

    private static let debtsKey = ImportExportService.debtsKey
    private let notifications = NotificationService.shared

    static func loadStoredDebts() -> [Debt] {
        guard let data = UserDefaults.standard.data(forKey: debtsKey),
              let decoded = try? JSONDecoder().decode([Debt].self, from: data) else {
            return []
        }
        return decoded
    }

    func loadDebts() {
        isLoading = true
        defer { isLoading = false }
        debts = Self.loadStoredDebts().sorted { $0.dateGiven > $1.dateGiven }
    }

    func saveDebts() {
        if let encoded = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(encoded, forKey: Self.debtsKey)
        }
    }

    var isFormValid: Bool {
        guard let value = AppCurrency.parseAmount(amount), value > 0 else { return false }
        return !personName.trimmed.isEmpty
    }

    /// Names of people from earlier debts, for quick re-entry.
    var knownPeople: [String] {
        var seen = Set<String>()
        return debts.map { $0.personName }.filter { seen.insert($0.lowercased()).inserted }
    }

    func addDebt() {
        guard isFormValid, let amountValue = AppCurrency.parseAmount(amount) else { return }

        let debt = Debt(
            personName: personName.trimmed,
            amount: amountValue,
            type: debtType,
            dateGiven: dateGiven,
            expectedReturnDate: hasExpectedReturnDate ? expectedReturnDate : nil,
            status: .active,
            note: note.trimmed,
            reminderEnabled: reminderEnabled && hasExpectedReturnDate,
            reminderDaysBefore: reminderDaysBefore
        )

        debts.insert(debt, at: 0)
        saveDebts()
        notifications.scheduleDebtReminder(for: debt)
        Haptics.success()
        resetForm()
    }

    func updateDebt() {
        guard var debt = editingDebt else { return }
        guard isFormValid, let amountValue = AppCurrency.parseAmount(amount) else { return }

        debt.personName = personName.trimmed
        debt.amount = amountValue
        debt.type = debtType
        debt.dateGiven = dateGiven
        debt.expectedReturnDate = hasExpectedReturnDate ? expectedReturnDate : nil
        debt.note = note.trimmed
        debt.reminderEnabled = reminderEnabled && hasExpectedReturnDate
        debt.reminderDaysBefore = reminderDaysBefore

        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index] = debt
            saveDebts()
            notifications.scheduleDebtReminder(for: debt)
            Haptics.success()
            resetForm()
        }
    }

    /// Частичный (или полный) возврат. Когда вернули всё — долг закрывается автоматически.
    func addRepayment(to debt: Debt, amount: Double, date: Date = Date(), note: String = "") {
        guard amount > 0, let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let payment = min(amount, debts[index].remainingAmount)
        guard payment > 0 else { return }

        debts[index].repayments.append(DebtRepayment(amount: payment, date: date, note: note))
        if debts[index].remainingAmount < 0.005 {
            debts[index].status = .returned
            debts[index].actualReturnDate = date
            notifications.cancelDebtReminder(id: debt.id)
        } else {
            notifications.scheduleDebtReminder(for: debts[index])
        }
        saveDebts()
        Haptics.success()
    }

    func deleteRepayment(_ repayment: DebtRepayment, from debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].repayments.removeAll { $0.id == repayment.id }
        if debts[index].status == .returned {
            debts[index].status = .active
            debts[index].actualReturnDate = nil
        }
        saveDebts()
        notifications.scheduleDebtReminder(for: debts[index])
    }

    func markAsReturned(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].status = .returned
        debts[index].actualReturnDate = Date()
        saveDebts()
        notifications.cancelDebtReminder(id: debt.id)
        Haptics.success()
    }

    func markAsActive(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].status = .active
        debts[index].actualReturnDate = nil
        // Reopening a debt that was closed by repayments would leave nothing to repay.
        if debts[index].remainingAmount <= 0 {
            debts[index].repayments.removeAll()
        }
        saveDebts()
        notifications.scheduleDebtReminder(for: debts[index])
    }

    func deleteDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
        saveDebts()
        notifications.cancelDebtReminder(id: debt.id)
    }

    func prepareNew() {
        resetForm()
    }

    func editDebt(_ debt: Debt) {
        editingDebt = debt
        personName = debt.personName
        amount = AppCurrency.editString(debt.amount)
        debtType = debt.type
        dateGiven = debt.dateGiven
        expectedReturnDate = debt.expectedReturnDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30)
        hasExpectedReturnDate = debt.expectedReturnDate != nil
        note = debt.note
        reminderEnabled = debt.reminderEnabled
        reminderDaysBefore = debt.reminderDaysBefore
    }

    func resetForm() {
        personName = ""
        amount = ""
        debtType = .given
        dateGiven = Date()
        expectedReturnDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
        hasExpectedReturnDate = true
        note = ""
        reminderEnabled = false
        reminderDaysBefore = 3
        editingDebt = nil
        showAddSheet = false
    }

    // MARK: - Computed Properties

    /// Мне должны (остаток по активным долгам)
    var totalGiven: Double {
        debts.filter { $0.type == .given && $0.status == .active }.reduce(0) { $0 + $1.remainingAmount }
    }

    /// Я должен (остаток по активным долгам)
    var totalReceived: Double {
        debts.filter { $0.type == .received && $0.status == .active }.reduce(0) { $0 + $1.remainingAmount }
    }

    var netDebt: Double {
        totalGiven - totalReceived
    }

    var activeDebts: [Debt] {
        debts.filter { $0.status == .active }
    }

    var overdueDebts: [Debt] {
        debts.filter { $0.isOverdue }
    }

    var dueSoonDebts: [Debt] {
        debts.filter { $0.isDueSoon }
    }

    var returnedDebts: [Debt] {
        debts.filter { $0.status == .returned }
    }

    var givenDebts: [Debt] {
        debts.filter { $0.type == .given }
    }

    var receivedDebts: [Debt] {
        debts.filter { $0.type == .received }
    }

    /// Balance with each person across all active debts: positive — they owe me.
    var balancesByPerson: [(name: String, balance: Double)] {
        var totals: [String: (name: String, balance: Double)] = [:]
        for debt in activeDebts {
            let key = debt.personName.lowercased()
            let signed = debt.type == .given ? debt.remainingAmount : -debt.remainingAmount
            let existing = totals[key] ?? (name: debt.personName, balance: 0)
            totals[key] = (name: existing.name, balance: existing.balance + signed)
        }
        return totals.values
            .filter { abs($0.balance) >= 0.005 }
            .sorted { abs($0.balance) > abs($1.balance) }
    }

    func getTotalGiven(for period: DatePeriod) -> Double {
        let filtered = givenDebts.filter { debt in
            period.contains(debt.dateGiven)
        }
        return filtered.reduce(0) { $0 + $1.amount }
    }

    func getTotalReceived(for period: DatePeriod) -> Double {
        let filtered = receivedDebts.filter { debt in
            period.contains(debt.dateGiven)
        }
        return filtered.reduce(0) { $0 + $1.amount }
    }
}

enum DatePeriod {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case all

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .thisWeek:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .thisYear:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .all:
            return true
        }
    }
}
