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
    /// Account the lent/borrowed money comes from / goes to; `nil` = don't touch balances.
    @Published var accountId: UUID?
    @Published var accounts: [Account] = []

    private static let debtsKey = ImportExportService.debtsKey
    private let notifications = NotificationService.shared
    private let database = DatabaseService.shared

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
        accounts = (try? database.fetchAccounts()) ?? []
    }

    func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return accounts.first { $0.id == id }?.displayName
    }

    // MARK: - Account balances

    /// Net money each account gained (+) or lost (−) because of this debt:
    /// lending takes money out, getting it back puts it in; borrowing is the opposite.
    private func balanceEffects(of debt: Debt) -> [UUID: Double] {
        let principalSign: Double = debt.type == .given ? -1 : 1
        var effects: [UUID: Double] = [:]
        if let accountId = debt.accountId {
            effects[accountId, default: 0] += principalSign * debt.amount
        }
        for repayment in debt.repayments {
            if let accountId = repayment.accountId {
                effects[accountId, default: 0] -= principalSign * repayment.amount
            }
        }
        return effects
    }

    /// Applies the difference between two states of a debt to the accounts
    /// (`nil` old = new debt, `nil` new = deleted debt).
    private func applyBalanceChange(from old: Debt?, to new: Debt?) {
        var delta: [UUID: Double] = [:]
        if let old = old {
            for (accountId, amount) in balanceEffects(of: old) {
                delta[accountId, default: 0] -= amount
            }
        }
        if let new = new {
            for (accountId, amount) in balanceEffects(of: new) {
                delta[accountId, default: 0] += amount
            }
        }
        for (accountId, amount) in delta where abs(amount) >= 0.005 {
            do {
                try database.adjustAccountBalance(id: accountId, by: amount)
            } catch {
                print("Error updating balance for debt: \(error)")
            }
        }
        accounts = (try? database.fetchAccounts()) ?? accounts
    }

    func saveDebts() {
        if let encoded = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(encoded, forKey: Self.debtsKey)
            NotificationCenter.default.post(name: .moneyDataDidChange, object: nil)
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
            accountId: accountId,
            reminderEnabled: reminderEnabled && hasExpectedReturnDate,
            reminderDaysBefore: reminderDaysBefore
        )

        debts.insert(debt, at: 0)
        saveDebts()
        applyBalanceChange(from: nil, to: debt)
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
        debt.accountId = accountId

        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            let old = debts[index]
            debts[index] = debt
            saveDebts()
            applyBalanceChange(from: old, to: debt)
            notifications.scheduleDebtReminder(for: debt)
            Haptics.success()
            resetForm()
        }
    }

    /// Частичный (или полный) возврат. Когда вернули всё — долг закрывается автоматически.
    /// The money goes to (or, for my own debt, comes from) `accountId`.
    func addRepayment(to debt: Debt, amount: Double, date: Date = Date(), note: String = "", accountId: UUID?) {
        guard amount > 0, let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let payment = min(amount, debts[index].remainingAmount)
        guard payment > 0 else { return }

        let old = debts[index]
        debts[index].repayments.append(DebtRepayment(amount: payment, date: date, note: note, accountId: accountId))
        if debts[index].remainingAmount < 0.005 {
            debts[index].status = .returned
            debts[index].actualReturnDate = date
            notifications.cancelDebtReminder(id: debt.id)
        } else {
            notifications.scheduleDebtReminder(for: debts[index])
        }
        saveDebts()
        applyBalanceChange(from: old, to: debts[index])
        Haptics.success()
    }

    func deleteRepayment(_ repayment: DebtRepayment, from debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let old = debts[index]
        debts[index].repayments.removeAll { $0.id == repayment.id }
        if debts[index].status == .returned {
            debts[index].status = .active
            debts[index].actualReturnDate = nil
        }
        saveDebts()
        applyBalanceChange(from: old, to: debts[index])
        notifications.scheduleDebtReminder(for: debts[index])
    }

    /// Closes the debt by recording the rest as one repayment, so the money reaches the account.
    func markAsReturned(_ debt: Debt, accountId: UUID? = nil) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let remaining = debts[index].remainingAmount
        if remaining > 0 {
            addRepayment(to: debt, amount: remaining, accountId: accountId ?? debt.accountId)
        } else {
            debts[index].status = .returned
            debts[index].actualReturnDate = Date()
            saveDebts()
            notifications.cancelDebtReminder(id: debt.id)
            Haptics.success()
        }
    }

    /// Reopens a closed debt. The repayment that closed it is undone (with its money).
    func markAsActive(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let old = debts[index]
        debts[index].status = .active
        debts[index].actualReturnDate = nil
        if debts[index].remainingAmount <= 0, !debts[index].repayments.isEmpty {
            debts[index].repayments.removeLast()
        }
        saveDebts()
        applyBalanceChange(from: old, to: debts[index])
        notifications.scheduleDebtReminder(for: debts[index])
    }

    /// Removing a debt also undoes its money movements on the accounts.
    func deleteDebt(_ debt: Debt) {
        guard let old = debts.first(where: { $0.id == debt.id }) else { return }
        debts.removeAll { $0.id == debt.id }
        saveDebts()
        applyBalanceChange(from: old, to: nil)
        notifications.cancelDebtReminder(id: debt.id)
    }

    func prepareNew() {
        resetForm()
        accountId = accounts.first?.id
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
        accountId = debt.accountId
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
        accountId = nil
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
