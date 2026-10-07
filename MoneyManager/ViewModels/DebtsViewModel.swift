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

    private let debtsKey = "debts"
    private let database = DatabaseService.shared

    func loadDebts() {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: debtsKey),
           let decoded = try? JSONDecoder().decode([Debt].self, from: data) {
            debts = decoded.sorted { $0.dateGiven > $1.dateGiven }
        }
    }

    func saveDebts() {
        if let encoded = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(encoded, forKey: debtsKey)
        }
    }

    func addDebt() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        guard !personName.isEmpty else { return }

        let debt = Debt(
            personName: personName,
            amount: amountValue,
            type: debtType,
            dateGiven: dateGiven,
            expectedReturnDate: hasExpectedReturnDate ? expectedReturnDate : nil,
            status: .active,
            note: note,
            reminderEnabled: reminderEnabled,
            reminderDaysBefore: reminderDaysBefore
        )

        debts.append(debt)
        saveDebts()
        resetForm()
    }

    func updateDebt() {
        guard var debt = editingDebt else { return }
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        guard !personName.isEmpty else { return }

        debt.personName = personName
        debt.amount = amountValue
        debt.type = debtType
        debt.dateGiven = dateGiven
        debt.expectedReturnDate = hasExpectedReturnDate ? expectedReturnDate : nil
        debt.note = note
        debt.reminderEnabled = reminderEnabled
        debt.reminderDaysBefore = reminderDaysBefore

        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index] = debt
            saveDebts()
            resetForm()
        }
    }

    func markAsReturned(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].status = .returned
        debts[index].actualReturnDate = Date()
        saveDebts()
    }

    func markAsActive(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        debts[index].status = .active
        debts[index].actualReturnDate = nil
        saveDebts()
    }

    func deleteDebt(_ debt: Debt) {
        debts.removeAll { $0.id == debt.id }
        saveDebts()
    }

    func editDebt(_ debt: Debt) {
        editingDebt = debt
        personName = debt.personName
        amount = String(debt.amount)
        debtType = debt.type
        dateGiven = debt.dateGiven
        expectedReturnDate = debt.expectedReturnDate ?? Date()
        hasExpectedReturnDate = debt.expectedReturnDate != nil
        note = debt.note
        reminderEnabled = debt.reminderEnabled
        reminderDaysBefore = debt.reminderDaysBefore
        showAddSheet = true
    }

    private func resetForm() {
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

    var totalGiven: Double {
        debts.filter { $0.type == .given && $0.status == .active }.reduce(0) { $0 + $1.amount }
    }

    var totalReceived: Double {
        debts.filter { $0.type == .received && $0.status == .active }.reduce(0) { $0 + $1.amount }
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
