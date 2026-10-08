import Foundation

class ImportExportService {
    static let shared = ImportExportService()
    private let database = DatabaseService.shared

    // UserDefaults keys used by the view models that keep data outside Core Data.
    static let debtsKey = "debts"
    static let goalsKey = "savingsGoals"
    static let billsKey = "bills"
    static let subscriptionsKey = "subscriptions"

    init() {}

    // MARK: - Export Functions

    func exportToCSV() throws -> URL {
        let transactions = try database.fetchTransactions()
        let categories = try database.fetchCategories()
        let accounts = try database.fetchAccounts()
        let dateFormatter = ISO8601DateFormatter()

        var csvString = "Date,Type,Amount,Category,Account,Note,Tags,Latitude,Longitude,Place\n"

        for transaction in transactions {
            let category = categories.first { $0.id == transaction.categoryId }?.name ?? "Unknown"
            let account = accounts.first { $0.id == transaction.accountId }?.name ?? "Unknown"
            let fields = [
                dateFormatter.string(from: transaction.date),
                transaction.type.rawValue,
                String(transaction.amount),
                category,
                account,
                transaction.note,
                transaction.tags.joined(separator: ";"),
                transaction.latitude.map { String($0) } ?? "",
                transaction.longitude.map { String($0) } ?? "",
                transaction.placeName ?? ""
            ]
            csvString += fields.map(csvEscape).joined(separator: ",") + "\n"
        }

        let fileURL = exportURL(extension: "csv")
        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func exportToJSON() throws -> URL {
        let exportData = ExportData(
            transactions: try database.fetchTransactions(includeCancelled: true),
            categories: try database.fetchCategories(),
            accounts: try database.fetchAccounts(),
            budgets: try database.fetchBudgets(),
            debts: loadStored([Debt].self, key: Self.debtsKey),
            goals: loadStored([SavingsGoal].self, key: Self.goalsKey),
            bills: loadStored([Bill].self, key: Self.billsKey),
            subscriptions: loadStored([Subscription].self, key: Self.subscriptionsKey),
            exportDate: Date(),
            version: "1.1"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(exportData)

        let fileURL = exportURL(extension: "json")
        try data.write(to: fileURL)
        return fileURL
    }

    private func exportURL(extension ext: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let fileName = "MoneyManager_\(formatter.string(from: Date())).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Splits one CSV line, honouring quoted fields.
    private func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = Array(line).makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    // Peek: a doubled quote is an escaped quote.
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Import Functions

    /// Files picked via `fileImporter` live outside the sandbox and need scoped access.
    private func withSecurityScope<T>(_ url: URL, _ body: () throws -> T) rethrows -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        return try body()
    }

    func importFromCSV(url: URL) throws -> Int {
        let content = try withSecurityScope(url) { try String(contentsOf: url, encoding: .utf8) }
        let lines = content.components(separatedBy: .newlines)

        guard lines.count > 1 else {
            throw ImportError.invalidFormat
        }

        var importCount = 0
        let categories = try database.fetchCategories()
        let accounts = try database.fetchAccounts()
        let dateFormatter = ISO8601DateFormatter()

        for line in lines.dropFirst() {
            let line = line.trimmed
            guard !line.isEmpty else { continue }

            let columns = csvFields(line)
            guard columns.count >= 6 else { continue }

            guard let date = dateFormatter.date(from: columns[0]) else { continue }
            guard let type = TransactionType(rawValue: columns[1]) else { continue }
            guard let amount = AppCurrency.parseAmount(columns[2]) else { continue }

            let categoryName = columns[3]
            let accountName = columns[4]
            let note = columns[5]
            let tags = columns.count > 6 && !columns[6].isEmpty ? columns[6].components(separatedBy: ";") : []

            let categoryType: CategoryType = type == .income ? .income : .expense
            let category = categories.first { $0.name == categoryName }
                ?? categories.first { $0.type == categoryType }
            let account = accounts.first { $0.name == accountName } ?? accounts.first

            guard let categoryId = category?.id, let accountId = account?.id else { continue }

            let transaction = Transaction(
                amount: amount,
                type: type,
                categoryId: categoryId,
                accountId: accountId,
                note: note,
                date: date,
                tags: tags,
                latitude: columns.count > 8 ? Double(columns[7]) : nil,
                longitude: columns.count > 8 ? Double(columns[8]) : nil,
                placeName: columns.count > 9 && !columns[9].isEmpty ? columns[9] : nil
            )

            try database.createTransaction(transaction)
            importCount += 1
        }

        return importCount
    }

    func importFromJSON(url: URL) throws -> ImportResult {
        let data = try withSecurityScope(url) { try Data(contentsOf: url) }
        let importData = try JSONDecoder().decode(ExportData.self, from: data)

        var result = ImportResult()

        // Skip records that already exist so restoring the same backup twice doesn't duplicate data.
        for category in importData.categories {
            do {
                guard try !database.categoryExists(id: category.id) else { continue }
                try database.createCategory(category)
                result.categoriesImported += 1
            } catch {
                result.errors.append("Failed to import category: \(category.name)")
            }
        }

        for account in importData.accounts {
            do {
                guard try !database.accountExists(id: account.id) else { continue }
                try database.createAccount(account)
                result.accountsImported += 1
            } catch {
                result.errors.append("Failed to import account: \(account.name)")
            }
        }

        for transaction in importData.transactions {
            do {
                guard try !database.transactionExists(id: transaction.id) else { continue }
                // Imported account balances already include these transactions.
                try database.createTransaction(transaction, adjustBalance: false)
                result.transactionsImported += 1
            } catch {
                result.errors.append("Failed to import transaction")
            }
        }

        for budget in importData.budgets {
            do {
                guard try !database.budgetExists(id: budget.id) else { continue }
                try database.createBudget(budget)
                result.budgetsImported += 1
            } catch {
                result.errors.append("Failed to import budget")
            }
        }

        result.otherImported += mergeStored(importData.debts, key: Self.debtsKey)
        result.otherImported += mergeStored(importData.goals, key: Self.goalsKey)
        result.otherImported += mergeStored(importData.bills, key: Self.billsKey)
        result.otherImported += mergeStored(importData.subscriptions, key: Self.subscriptionsKey)

        return result
    }

    // MARK: - UserDefaults-backed data

    private func loadStored<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func mergeStored<T: Codable & Identifiable>(_ items: [T]?, key: String) -> Int where T.ID == UUID {
        guard let items = items, !items.isEmpty else { return 0 }
        var existing = loadStored([T].self, key: key) ?? []
        let existingIds = Set(existing.map { $0.id })
        let newItems = items.filter { !existingIds.contains($0.id) }
        existing.append(contentsOf: newItems)
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return newItems.count
    }

    // MARK: - Backup & Restore

    func createBackup() throws -> URL {
        return try exportToJSON()
    }

    func restoreFromBackup(url: URL) throws -> ImportResult {
        return try importFromJSON(url: url)
    }
}

struct ExportData: Codable {
    let transactions: [Transaction]
    let categories: [Category]
    let accounts: [Account]
    let budgets: [Budget]
    // Optional so backups made by version 1.0 still decode.
    let debts: [Debt]?
    let goals: [SavingsGoal]?
    let bills: [Bill]?
    let subscriptions: [Subscription]?
    let exportDate: Date
    let version: String
}

struct ImportResult {
    var transactionsImported: Int = 0
    var categoriesImported: Int = 0
    var accountsImported: Int = 0
    var budgetsImported: Int = 0
    var otherImported: Int = 0
    var errors: [String] = []

    var totalImported: Int {
        transactionsImported + categoriesImported + accountsImported + budgetsImported + otherImported
    }
}

enum ImportError: LocalizedError {
    case invalidFormat
    case fileNotFound
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "The file format is not supported.".localized
        case .fileNotFound: return "The file could not be found.".localized
        case .parsingError: return "The file could not be read.".localized
        }
    }
}
