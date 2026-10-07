import Foundation
import SwiftUI

@MainActor
class CategoryViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var expenseCategories: [Category] = []
    @Published var incomeCategories: [Category] = []
    @Published var isLoading: Bool = false
    @Published var showAddSheet: Bool = false
    @Published var editingCategory: Category?

    @Published var categoryName: String = ""
    @Published var categoryIcon: String = "tag.fill"
    @Published var categoryColor: String = "#3498DB"
    @Published var categoryType: CategoryType = .expense
    @Published var budgetLimit: String = ""

    private let database = DatabaseService.shared

    let icons = [
        "fork.knife", "car.fill", "bag.fill", "gamecontroller.fill",
        "doc.text.fill", "heart.fill", "book.fill", "airplane",
        "dollarsign.circle.fill", "briefcase.fill", "chart.line.uptrend.xyaxis",
        "gift.fill", "plus.circle.fill", "tag.fill", "ellipsis.circle"
    ]

    let colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#2ECC71", "#3498DB",
        "#9B59B6", "#E74C3C", "#1ABC9C", "#95A5A6"
    ]

    func loadCategories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            expenseCategories = try database.fetchCategories(type: .expense)
            incomeCategories = try database.fetchCategories(type: .income)
            categories = expenseCategories + incomeCategories
        } catch {
            print("Error loading categories: \(error)")
        }
    }

    func addCategory() async {
        guard !categoryName.isEmpty else { return }

        let category = Category(
            name: categoryName,
            icon: categoryIcon,
            color: categoryColor,
            type: categoryType,
            budgetLimit: Double(budgetLimit)
        )

        do {
            try database.createCategory(category)
            await loadCategories()
            resetForm()
        } catch {
            print("Error creating category: \(error)")
        }
    }

    func updateCategory() async {
        guard var category = editingCategory else { return }
        guard !categoryName.isEmpty else { return }

        category.name = categoryName
        category.icon = categoryIcon
        category.color = categoryColor
        category.type = categoryType
        category.budgetLimit = Double(budgetLimit)

        do {
            try database.updateCategory(category)
            await loadCategories()
            resetForm()
        } catch {
            print("Error updating category: \(error)")
        }
    }

    func deleteCategory(_ category: Category) async {
        do {
            try database.deleteCategory(id: category.id)
            await loadCategories()
        } catch {
            print("Error deleting category: \(error)")
        }
    }

    func editCategory(_ category: Category) {
        editingCategory = category
        categoryName = category.name
        categoryIcon = category.icon
        categoryColor = category.color
        categoryType = category.type
        budgetLimit = category.budgetLimit.map { String($0) } ?? ""
        showAddSheet = true
    }

    private func resetForm() {
        categoryName = ""
        categoryIcon = "tag.fill"
        categoryColor = "#3498DB"
        categoryType = .expense
        budgetLimit = ""
        editingCategory = nil
        showAddSheet = false
    }

    func initializeDefaultCategories() async {
        do {
            let existingCategories = try database.fetchCategories()
            if existingCategories.isEmpty {
                for category in Category.defaultExpenseCategories {
                    try database.createCategory(category)
                }
                for category in Category.defaultIncomeCategories {
                    try database.createCategory(category)
                }
            }
        } catch {
            print("Error initializing default categories: \(error)")
        }
    }
}
