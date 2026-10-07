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

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let categoryTotals = try? database.getTransactionsByCategory(from: startOfMonth, to: endOfMonth)
        let categories = try? database.fetchCategories(type: .expense)

        for budget in budgets {
            let category = categories?.first { $0.id == budget.categoryId }
            let spent = categoryTotals?[budget.categoryId ?? UUID()] ?? 0
            let remaining = budget.amount - spent
            let percentage = budget.amount > 0 ? (spent / budget.amount) * 100 : 0

            let summary = BudgetSummary(
                category: category,
                budget: budget,
                spent: spent,
                remaining: remaining,
                percentage: percentage
            )
            summaries.append(summary)
        }

        budgetSummaries = summaries
    }

    func addBudget() async {
        guard let amount = Double(budgetAmount), amount > 0 else { return }

        let budget = Budget(
            categoryId: selectedCategory?.id,
            amount: amount,
            period: budgetPeriod
        )

        do {
            try database.createBudget(budget)
            await loadBudgets()
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

    private func resetForm() {
        selectedCategory = nil
        budgetAmount = ""
        budgetPeriod = .monthly
        showAddSheet = false
    }
}
