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
        "fork.knife", "cart.fill", "car.fill", "bus.fill", "fuelpump.fill",
        "bag.fill", "tshirt.fill", "gamecontroller.fill", "film.fill",
        "doc.text.fill", "bolt.fill", "wifi", "phone.fill", "house.fill",
        "heart.fill", "cross.case.fill", "pills.fill", "book.fill",
        "graduationcap.fill", "airplane", "pawprint.fill", "figure.walk",
        "gift.fill", "cup.and.saucer.fill", "scissors", "wrench.and.screwdriver.fill",
        "dollarsign.circle.fill", "briefcase.fill", "chart.line.uptrend.xyaxis",
        "banknote.fill", "creditcard.fill", "plus.circle.fill", "tag.fill", "ellipsis.circle"
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

    var isFormValid: Bool {
        !categoryName.trimmed.isEmpty && (budgetLimit.trimmed.isEmpty || AppCurrency.parseAmount(budgetLimit) != nil)
    }

    @discardableResult
    func addCategory() async -> Category? {
        guard isFormValid else { return nil }

        let category = Category(
            name: categoryName.trimmed,
            icon: categoryIcon,
            color: categoryColor,
            type: categoryType,
            budgetLimit: AppCurrency.parseAmount(budgetLimit),
            sortOrder: (categories.map { $0.sortOrder }.filter { $0 < 99 }.max() ?? 0) + 1
        )

        do {
            try database.createCategory(category)
            await loadCategories()
            resetForm()
            return category
        } catch {
            print("Error creating category: \(error)")
            return nil
        }
    }

    func updateCategory() async {
        guard var category = editingCategory else { return }
        guard isFormValid else { return }

        category.name = categoryName.trimmed
        category.icon = categoryIcon
        category.color = categoryColor
        category.type = categoryType
        category.budgetLimit = AppCurrency.parseAmount(budgetLimit)

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
        budgetLimit = category.budgetLimit.map { AppCurrency.editString($0) } ?? ""
        showAddSheet = true
    }

    func prepareNew(type: CategoryType = .expense) {
        resetForm()
        categoryType = type
    }

    func resetForm() {
        categoryName = ""
        categoryIcon = "tag.fill"
        categoryColor = "#3498DB"
        categoryType = .expense
        budgetLimit = ""
        editingCategory = nil
        showAddSheet = false
    }

    func initializeDefaultCategories() async {
        database.seedDefaultsIfNeeded()
        await loadCategories()
    }
}
