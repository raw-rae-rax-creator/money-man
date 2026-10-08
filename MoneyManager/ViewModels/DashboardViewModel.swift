import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var totalBalance: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlyExpenses: Double = 0
    @Published var recentTransactions: [Transaction] = []
    @Published var categoryBreakdown: [(category: Category, amount: Double, percentage: Double)] = []
    @Published var accounts: [Account] = []
    @Published var categoriesById: [UUID: Category] = [:]
    @Published var accountsById: [UUID: Account] = [:]
    @Published var isLoading: Bool = false

    // Debts are tracked separately and never affect balance or income/expense stats.
    @Published var owedToMe: Double = 0
    @Published var iOwe: Double = 0
    @Published var activeDebtsCount: Int = 0
    @Published var overdueDebtsCount: Int = 0

    private let database = DatabaseService.shared

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            accounts = try database.fetchAccounts()
            accountsById = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            totalBalance = accounts.filter { $0.includeInTotal }.reduce(0) { $0 + $1.balance }

            let month = Date().interval(of: .month)
            let monthTransactions = try database.fetchTransactions(from: month.start, to: month.end)
            monthlyIncome = monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            monthlyExpenses = monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

            let allTransactions = try database.fetchTransactions()
            recentTransactions = Array(allTransactions.prefix(10))

            let categories = try database.fetchCategories()
            categoriesById = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            var categoryTotals: [UUID: Double] = [:]
            for transaction in monthTransactions where transaction.type == .expense {
                categoryTotals[transaction.categoryId, default: 0] += transaction.amount
            }

            let expenses = monthlyExpenses
            var breakdown: [(category: Category, amount: Double, percentage: Double)] = []
            for (categoryId, amount) in categoryTotals where amount > 0 {
                guard let category = categoriesById[categoryId] else { continue }
                let percentage = expenses > 0 ? (amount / expenses) * 100 : 0
                breakdown.append((category: category, amount: amount, percentage: percentage))
            }
            categoryBreakdown = breakdown.sorted { $0.amount > $1.amount }
        } catch {
            print("Error loading dashboard data: \(error)")
        }

        loadDebtsSummary()
    }

    private func loadDebtsSummary() {
        let debts = DebtsViewModel.loadStoredDebts().filter { $0.status == .active }
        owedToMe = debts.filter { $0.type == .given }.reduce(0) { $0 + $1.remainingAmount }
        iOwe = debts.filter { $0.type == .received }.reduce(0) { $0 + $1.remainingAmount }
        activeDebtsCount = debts.count
        overdueDebtsCount = debts.filter { $0.isOverdue }.count
    }

    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try database.deleteTransaction(id: transaction.id)
            await loadData()
        } catch {
            print("Error deleting transaction: \(error)")
        }
    }
}
