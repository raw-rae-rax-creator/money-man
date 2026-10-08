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
    @Published var categoriesById: [UUID: Category] = [:]
    @Published var accountsById: [UUID: Account] = [:]

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
            let categories = try database.fetchCategories()
            let accounts = try database.fetchAccounts()
            categoriesById = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            accountsById = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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

        let query = searchText.trimmed
        if !query.isEmpty {
            filteredTransactions = filteredTransactions.filter { transaction in
                transaction.note.localizedCaseInsensitiveContains(query) ||
                transaction.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||
                (categoriesById[transaction.categoryId]?.name.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
    }

    /// Transactions grouped by calendar day, newest first.
    var groupedTransactions: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredTransactions) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try database.deleteTransaction(id: transaction.id)
        } catch {
            print("Error deleting transaction: \(error)")
        }
        await loadTransactions()
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
        let now = Date()

        switch dateRange {
        case .today:
            let day = now.interval(of: .day)
            return (day.start, day.end)
        case .thisWeek:
            let week = now.interval(of: .weekOfYear)
            return (week.start, week.end)
        case .thisMonth:
            let month = now.interval(of: .month)
            return (month.start, month.end)
        case .thisYear:
            let year = now.interval(of: .year)
            return (year.start, year.end)
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
