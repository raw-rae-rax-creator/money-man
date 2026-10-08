import Foundation
import SwiftUI

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var budgetSummaries: [BudgetSummary] = []
    @Published var isLoading: Bool = false
    @Published var showAddSheet: Bool = false

    @Published var selectedCategory: Category?
    @Published var budgetAmount: String = ""
    @Published var budgetPeriod: BudgetPeriod = .monthly

    private let database = DatabaseService.shared

    var isFormValid: Bool {
        guard let amount = AppCurrency.parseAmount(budgetAmount) else { return false }
        return amount > 0
    }

    func loadBudgets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            budgets = try database.fetchBudgets()
            await calculateBudgetSummaries()
        } catch {
            print("Error loading budgets: \(error)")
        }
    }

    func calculateBudgetSummaries() async {
        var summaries: [BudgetSummary] = []
        let categories = (try? database.fetchCategories(type: .expense)) ?? []

        for budget in budgets {
            // Each budget is measured against its own period (week / month / year).
            let period = Date().interval(of: budget.period.calendarComponent)
            let expenses = ((try? database.fetchTransactions(from: period.start, to: period.end)) ?? [])
                .filter { $0.type == .expense }

            let spent: Double
            if let categoryId = budget.categoryId {
                spent = expenses.filter { $0.categoryId == categoryId }.reduce(0) { $0 + $1.amount }
            } else {
                // "Total Budget" covers all expenses.
                spent = expenses.reduce(0) { $0 + $1.amount }
            }

            let category = categories.first { $0.id == budget.categoryId }
            let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0

            summaries.append(BudgetSummary(
                category: category,
                budget: budget,
                spent: spent,
                remaining: budget.amount - spent,
                percentage: percentage
            ))
        }

        budgetSummaries = summaries
    }

    func addBudget() async {
        guard isFormValid, let amount = AppCurrency.parseAmount(budgetAmount) else { return }

        let budget = Budget(
            categoryId: selectedCategory?.id,
            amount: amount,
            period: budgetPeriod
        )

        do {
            try database.createBudget(budget)
            await loadBudgets()
            Haptics.success()
            resetForm()
        } catch {
            print("Error creating budget: \(error)")
        }
    }

    func deleteBudget(_ budget: Budget) async {
        do {
            try database.deleteBudget(id: budget.id)
            await loadBudgets()
        } catch {
            print("Error deleting budget: \(error)")
        }
    }

    func resetForm() {
        selectedCategory = nil
        budgetAmount = ""
        budgetPeriod = .monthly
        showAddSheet = false
    }
}
