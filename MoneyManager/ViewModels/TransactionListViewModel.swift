import Foundation
import SwiftUI

@MainActor
class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var filteredTransactions: [Transaction] = []
    @Published var selectedFilter: TransactionFilter = .all
    @Published var searchText: String = ""
    @Published var selectedCategory: Category?
    @Published var dateRange: DateRange = .thisMonth
    @Published var isLoading: Bool = false

    private let database = DatabaseService.shared

    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case income = "Income"
        case expense = "Expense"
    }

    enum DateRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisYear = "This Year"
        case all = "All Time"
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (from, to) = getDateRange()
            transactions = try database.fetchTransactions(from: from, to: to)
            applyFilters()
        } catch {
            print("Error loading transactions: \(error)")
        }
    }

    func applyFilters() {
        filteredTransactions = transactions

        if selectedFilter != .all {
            let type: TransactionType = selectedFilter == .income ? .income : .expense
            filteredTransactions = filteredTransactions.filter { $0.type == type }
        }

        if let category = selectedCategory {
            filteredTransactions = filteredTransactions.filter { $0.categoryId == category.id }
        }

        if !searchText.isEmpty {
            filteredTransactions = filteredTransactions.filter {
                $0.note.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

    func deleteTransaction(at offsets: IndexSet) async {
        for index in offsets {
            let transaction = filteredTransactions[index]
            do {
                try database.deleteTransaction(id: transaction.id)
            } catch {
                print("Error deleting transaction: \(error)")
            }
        }
        await loadTransactions()
    }

    private func getDateRange() -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (start, now)
        case .all:
            return (nil, nil)
        }
    }

    func getTotalIncome() -> Double {
        filteredTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    func getTotalExpenses() -> Double {
        filteredTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func getNetAmount() -> Double {
        getTotalIncome() - getTotalExpenses()
    }
}
