import Foundation
import SwiftUI

@MainActor
class AddTransactionViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var type: TransactionType = .expense
    @Published var selectedCategory: Category?
    @Published var selectedAccount: Account? = nil
    @Published var note: String = ""
    @Published var date: Date = Date()
    @Published var isRecurring: Bool = false
    @Published var recurringFrequency: RecurringFrequency = .monthly
    @Published var tags: [String] = []
    @Published var newTag: String = ""

    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var isSaving: Bool = false

    let editingTransaction: Transaction?
    private let database = DatabaseService.shared

    var isEditing: Bool { editingTransaction != nil }

    init(editing transaction: Transaction? = nil) {
        editingTransaction = transaction
        if let transaction = transaction {
            amount = AppCurrency.editString(transaction.amount)
            type = transaction.type
            note = transaction.note
            date = transaction.date
            isRecurring = transaction.isRecurring
            recurringFrequency = transaction.recurringFrequency ?? .monthly
            tags = transaction.tags
        }
    }

    func loadData() async {
        do {
            let categoryType: CategoryType = type == .income ? .income : .expense
            categories = try database.fetchCategories(type: categoryType)
            accounts = try database.fetchAccounts()

            // Keep the current choice only if it's valid for the selected type,
            // otherwise an income could end up saved with an expense category.
            if !categories.contains(where: { $0.id == selectedCategory?.id }) {
                selectedCategory = categories.first { $0.id == editingTransaction?.categoryId } ?? categories.first
            }

            if !accounts.contains(where: { $0.id == selectedAccount?.id }) {
                selectedAccount = accounts.first { $0.id == editingTransaction?.accountId } ?? accounts.first
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }

    func addTag() {
        let trimmed = newTag.trimmed
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save() async -> Bool {
        guard validate(),
              let amountValue = AppCurrency.parseAmount(amount),
              let category = selectedCategory,
              let account = selectedAccount else {
            showError = true
            Haptics.error()
            return false
        }

        isSaving = true
        defer { isSaving = false }

        // A tag typed but not confirmed with "+" is still meant to be saved.
        addTag()

        do {
            if var transaction = editingTransaction {
                transaction.amount = amountValue
                transaction.type = type
                transaction.categoryId = category.id
                transaction.accountId = account.id
                transaction.note = note.trimmed
                transaction.date = date
                transaction.isRecurring = isRecurring
                transaction.recurringFrequency = isRecurring ? recurringFrequency : nil
                transaction.tags = tags
                try database.updateTransaction(transaction)
            } else {
                let transaction = Transaction(
                    amount: amountValue,
                    type: type,
                    categoryId: category.id,
                    accountId: account.id,
                    note: note.trimmed,
                    date: date,
                    isRecurring: isRecurring,
                    recurringFrequency: isRecurring ? recurringFrequency : nil,
                    tags: tags
                )
                try database.createTransaction(transaction)
            }

            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Haptics.error()
            return false
        }
    }

    func delete() async -> Bool {
        guard let transaction = editingTransaction else { return false }
        do {
            try database.deleteTransaction(id: transaction.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    private func validate() -> Bool {
        guard let amountValue = AppCurrency.parseAmount(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return false
        }

        guard selectedCategory != nil else {
            errorMessage = "Please select a category"
            return false
        }

        guard selectedAccount != nil else {
            errorMessage = "Please select an account"
            return false
        }

        return true
    }

    func reset() {
        amount = ""
        note = ""
        date = Date()
        isRecurring = false
        tags = []
        newTag = ""
    }
}
