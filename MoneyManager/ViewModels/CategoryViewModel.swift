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

    /// Drag-to-reorder in the category list. The order is used everywhere categories are picked.
    func moveCategories(type: CategoryType, from source: IndexSet, to destination: Int) {
        var list = type == .income ? incomeCategories : expenseCategories
        list.move(fromOffsets: source, toOffset: destination)
        saveOrder(list, type: type)
    }

    /// Most used categories first.
    func sortByUsage(type: CategoryType) {
        let counts = (try? database.categoryUsageCounts()) ?? [:]
        let list = type == .income ? incomeCategories : expenseCategories
        // Stable: equal counts keep their current relative order.
        let sorted = list.enumerated().sorted { lhs, rhs in
            let left = counts[lhs.element.id] ?? 0
            let right = counts[rhs.element.id] ?? 0
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map { $0.element }
        saveOrder(sorted, type: type)
    }

    private func saveOrder(_ list: [Category], type: CategoryType) {
        var ordered = list
        for index in ordered.indices {
            ordered[index].sortOrder = index + 1
        }
        if type == .income {
            incomeCategories = ordered
        } else {
            expenseCategories = ordered
        }
        categories = expenseCategories + incomeCategories

        do {
            try database.updateCategoryOrder(ordered.map { $0.id })
        } catch {
            print("Error saving category order: \(error)")
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
        categoryName = category.displayName
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
