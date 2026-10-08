import Foundation
import SwiftUI

@MainActor
class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var showAddSheet: Bool = false
    @Published var editingAccount: Account?

    @Published var name: String = ""
    @Published var type: AccountType = .cash
    @Published var balance: String = ""
    @Published var color: String = "#3498DB"
    @Published var includeInTotal: Bool = true
    @Published var errorMessage: String?

    private let database = DatabaseService.shared

    let colors = [
        "#2ECC71", "#3498DB", "#9B59B6", "#E74C3C", "#F39C12",
        "#1ABC9C", "#34495E", "#FF6B6B", "#45B7D1", "#95A5A6"
    ]

    func loadAccounts() {
        do {
            accounts = try database.fetchAccounts()
        } catch {
            print("Error loading accounts: \(error)")
        }
    }

    var totalBalance: Double {
        accounts.filter { $0.includeInTotal }.reduce(0) { $0 + $1.balance }
    }

    var isFormValid: Bool {
        !name.trimmed.isEmpty && (balance.trimmed.isEmpty || AppCurrency.parseAmount(balance) != nil)
    }

    func toggleBalanceSign() {
        if balance.hasPrefix("-") {
            balance.removeFirst()
        } else {
            balance = "-" + (balance.isEmpty ? "0" : balance)
        }
    }

    func prepareNew() {
        editingAccount = nil
        name = ""
        type = .cash
        balance = ""
        color = "#3498DB"
        includeInTotal = true
    }

    func edit(_ account: Account) {
        editingAccount = account
        name = account.displayName
        type = account.type
        balance = AppCurrency.editString(account.balance)
        color = account.color
        includeInTotal = account.includeInTotal
        showAddSheet = true
    }

    @discardableResult
    func save() -> Account? {
        guard isFormValid else { return nil }
        let balanceValue = AppCurrency.parseAmount(balance) ?? 0

        do {
            let saved: Account
            if var account = editingAccount {
                account.name = name.trimmed
                account.type = type
                account.icon = type.icon
                account.balance = balanceValue
                account.color = color
                account.includeInTotal = includeInTotal
                try database.updateAccount(account)
                saved = account
            } else {
                saved = Account(
                    name: name.trimmed,
                    type: type,
                    balance: balanceValue,
                    icon: type.icon,
                    color: color,
                    includeInTotal: includeInTotal
                )
                try database.createAccount(saved)
            }
            loadAccounts()
            prepareNew()
            showAddSheet = false
            return saved
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(_ account: Account) {
        do {
            try database.deleteAccount(id: account.id)
            loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
