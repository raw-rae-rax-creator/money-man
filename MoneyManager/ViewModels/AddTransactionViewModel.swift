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

    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var placeName: String?
    @Published var isLocating: Bool = false

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
            latitude = transaction.latitude
            longitude = transaction.longitude
            placeName = transaction.placeName
        }
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    /// Tags a new transaction with the current location when the setting is on.
    func captureLocationIfNeeded() async {
        guard !isEditing,
              !hasLocation,
              UserDefaults.standard.bool(forKey: AppPreferences.saveLocationKey) else { return }

        isLocating = true
        defer { isLocating = false }

        guard let location = await LocationService.shared.currentLocation() else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        placeName = await LocationService.shared.placeName(for: location)
    }

    func removeLocation() {
        latitude = nil
        longitude = nil
        placeName = nil
    }

    func loadData() async {
        do {
            let categoryType: CategoryType = type == .income ? .income : .expense
            categories = try database.fetchCategories(type: categoryType)
            accounts = try database.fetchAccounts()

            // Keep the current choice only if it's valid for the selected type,
            // otherwise an income could end up saved with an expense category.
            // Re-pick from the fresh lists (by id): pickers match their selection with ==,
            // and a stale copy with an old balance or name would no longer match any row.
            let categoryId = selectedCategory?.id ?? editingTransaction?.categoryId
            selectedCategory = categories.first { $0.id == categoryId } ?? categories.first

            let accountId = selectedAccount?.id ?? editingTransaction?.accountId
            selectedAccount = accounts.first { $0.id == accountId } ?? accounts.first
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
                transaction.latitude = latitude
                transaction.longitude = longitude
                transaction.placeName = placeName
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
                    tags: tags,
                    latitude: latitude,
                    longitude: longitude,
                    placeName: placeName
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

    var isCancelled: Bool {
        editingTransaction?.isCancelled ?? false
    }

    /// Cancels instead of deleting: the money goes back to the account, the transaction stays visible.
    func cancelTransaction() async -> Bool {
        guard let transaction = editingTransaction else { return false }
        do {
            try database.cancelTransaction(id: transaction.id)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    func restoreTransaction() async -> Bool {
        guard let transaction = editingTransaction else { return false }
        do {
            try database.restoreTransaction(id: transaction.id)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    /// Permanent removal, offered only for cancelled transactions.
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
            errorMessage = "Please enter a valid amount".localized
            return false
        }

        guard selectedCategory != nil else {
            errorMessage = "Please select a category".localized
            return false
        }

        guard selectedAccount != nil else {
            errorMessage = "Please select an account".localized
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
