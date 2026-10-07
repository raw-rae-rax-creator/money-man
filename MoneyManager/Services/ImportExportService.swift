import Foundation

class ImportExportService {
    static let shared = ImportExportService()
    private let database = DatabaseService.shared

    init() {}

    // MARK: - Export Functions

    func exportToCSV() throws -> URL {
        let transactions = try database.fetchTransactions()
        let categories = try database.fetchCategories()
        let accounts = try database.fetchAccounts()

        var csvString = "Date,Type,Amount,Category,Account,Note,Tags\n"

        for transaction in transactions {
            let category = categories.first { $0.id == transaction.categoryId }?.name ?? "Unknown"
            let account = accounts.first { $0.id == transaction.accountId }?.name ?? "Unknown"
            let tags = transaction.tags.joined(separator: ";")

            let dateFormatter = ISO8601DateFormatter()
            let dateString = dateFormatter.string(from: transaction.date)

            csvString += "\(dateString),\(transaction.type.rawValue),\(transaction.amount),\(category),\(account),\(transaction.note),\(tags)\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "MoneyManager_Export_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    func exportToJSON() throws -> URL {
        let transactions = try database.fetchTransactions()
        let categories = try database.fetchCategories()
        let accounts = try database.fetchAccounts()
        let budgets = try database.fetchBudgets()

        let exportData = ExportData(
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            budgets: budgets,
            exportDate: Date(),
            version: "1.0"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(exportData)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "MoneyManager_Export_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL)

        return fileURL
    }

    // MARK: - Import Functions

    func importFromCSV(url: URL) throws -> Int {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        guard lines.count > 1 else {
            throw ImportError.invalidFormat
        }

        var importCount = 0
        let categories = try database.fetchCategories()
        let accounts = try database.fetchAccounts()

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 6 else { continue }

            let dateFormatter = ISO8601DateFormatter()
            guard let date = dateFormatter.date(from: columns[0]) else { continue }
            guard let type = TransactionType(rawValue: columns[1]) else { continue }
            guard let amount = Double(columns[2]) else { continue }

            let categoryName = columns[3]
            let accountName = columns[4]
            let note = columns[5]
            let tags = columns.count > 6 ? columns[6].components(separatedBy: ";") : []

            let category = categories.first { $0.name == categoryName }
            let account = accounts.first { $0.name == accountName }

            guard let categoryId = category?.id, let accountId = account?.id else { continue }

            let transaction = Transaction(
                amount: amount,
                type: type,
                categoryId: categoryId,
                accountId: accountId,
                note: note,
                date: date,
                tags: tags
            )

            try database.createTransaction(transaction)
            importCount += 1
        }

        return importCount
    }

    func importFromJSON(url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let importData = try decoder.decode(ExportData.self, from: data)

        var result = ImportResult()

        for category in importData.categories {
            do {
                try database.createCategory(category)
                result.categoriesImported += 1
            } catch {
                result.errors.append("Failed to import category: \(category.name)")
            }
        }

        for account in importData.accounts {
            do {
                try database.createAccount(account)
                result.accountsImported += 1
            } catch {
                result.errors.append("Failed to import account: \(account.name)")
            }
        }

        for transaction in importData.transactions {
            do {
                try database.createTransaction(transaction)
                result.transactionsImported += 1
            } catch {
                result.errors.append("Failed to import transaction")
            }
        }

        for budget in importData.budgets {
            do {
                try database.createBudget(budget)
                result.budgetsImported += 1
            } catch {
                result.errors.append("Failed to import budget")
            }
        }

        return result
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
    let exportDate: Date
    let version: String
}

struct ImportResult {
    var transactionsImported: Int = 0
    var categoriesImported: Int = 0
    var accountsImported: Int = 0
    var budgetsImported: Int = 0
    var errors: [String] = []

    var totalImported: Int {
        transactionsImported + categoriesImported + accountsImported + budgetsImported
    }
}

enum ImportError: Error {
    case invalidFormat
    case fileNotFound
    case parsingError
}
