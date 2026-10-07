import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var totalBalance: Double = 0
    @Published var monthlyIncome: Double = 0
    @Published var monthlyExpenses: Double = 0
    @Published var recentTransactions: [Transaction] = []
    @Published var categoryBreakdown: [(category: Category, amount: Double, percentage: Double)] = []
    @Published var isLoading: Bool = false

    private let database = DatabaseService.shared

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            totalBalance = try database.getTotalBalance()

            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

            monthlyIncome = try database.getMonthlyIncome(from: startOfMonth, to: endOfMonth)
            monthlyExpenses = try database.getMonthlyExpenses(from: startOfMonth, to: endOfMonth)

            let allTransactions = try database.fetchTransactions()
            recentTransactions = Array(allTransactions.prefix(10))

            let categoryTotals = try database.getTransactionsByCategory(from: startOfMonth, to: endOfMonth)
            let categories = try database.fetchCategories(type: .expense)
            let totalExpenses = categoryTotals.values.reduce(0, +)

            categoryBreakdown = categories.compactMap { category in
                if let amount = categoryTotals[category.id], amount > 0 {
                    let percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0
                    return (category: category, amount: amount, percentage: percentage)
                }
                return nil
            }.sorted { $0.amount > $1.amount }

        } catch {
            print("Error loading dashboard data: \(error)")
        }
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
