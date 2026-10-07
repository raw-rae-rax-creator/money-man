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

    private let database = DatabaseService.shared

    func loadData() async {
        do {
            let categoryType: CategoryType = type == .income ? .income : .expense
            categories = try database.fetchCategories(type: categoryType)
            accounts = try database.fetchAccounts()

            if selectedCategory == nil && !categories.isEmpty {
                selectedCategory = categories.first
            }
            if selectedAccount == nil && !accounts.isEmpty {
                selectedAccount = accounts.first
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }

    func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save() async -> Bool {
        guard validate() else {
            showError = true
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let amountValue = Double(amount),
                  let category = selectedCategory,
                  let account = selectedAccount else {
                errorMessage = "Invalid data"
                return false
            }

            let transaction = Transaction(
                amount: amountValue,
                type: type,
                categoryId: category.id,
                accountId: account.id,
                note: note,
                date: date,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil,
                tags: tags
            )

            try database.createTransaction(transaction)

            var updatedAccount = account
            if type == .income {
                updatedAccount.balance += amountValue
            } else {
                updatedAccount.balance -= amountValue
            }
            try database.updateAccount(updatedAccount)

            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    private func validate() -> Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
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
