import Foundation
import CoreData

class DatabaseService {
    static let shared = DatabaseService()
    private let container: NSPersistentContainer
    private let seededKey = "didSeedDefaults"

    private init() {
        container = NSPersistentContainer(name: "MoneyManagerModel")

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError = loadError {
            // Builds before the schema fix marked nullable attributes as required, so
            // nothing could be saved and the old store can't be migrated. Start fresh.
            print("Core Data failed to load, recreating store: \(loadError.localizedDescription)")
            if let url = container.persistentStoreDescriptions.first?.url {
                try? container.persistentStoreCoordinator.destroyPersistentStore(
                    at: url,
                    ofType: NSSQLiteStoreType,
                    options: nil
                )
            }
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("Core Data failed to load: \(error.localizedDescription)")
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var context: NSManagedObjectContext {
        return container.viewContext
    }

    func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            print("Error saving context: \(error)")
            throw error
        }
    }

    /// Creates default categories and a "Cash" account on first launch so the user
    /// can add a transaction right away.
    func seedDefaultsIfNeeded() {
        do {
            if try fetchCategories().isEmpty {
                for category in Category.defaultExpenseCategories + Category.defaultIncomeCategories {
                    try createCategory(category)
                }
            }

            if !UserDefaults.standard.bool(forKey: seededKey) {
                if try fetchAccounts().isEmpty {
                    try createAccount(Account(
                        name: "Cash",
                        type: .cash,
                        icon: AccountType.cash.icon,
                        color: "#2ECC71"
                    ))
                }
                UserDefaults.standard.set(true, forKey: seededKey)
            }
        } catch {
            print("Error seeding defaults: \(error)")
        }
    }

    private func fetchEntity<T: NSManagedObject>(_ type: T.Type, named entityName: String, id: UUID) throws -> T? {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Transaction Operations

    private func balanceEffect(type: TransactionType, amount: Double) -> Double {
        switch type {
        case .income: return amount
        case .expense: return -amount
        case .transfer: return 0
        }
    }

    private func adjustBalance(accountId: UUID, by delta: Double) throws {
        guard delta != 0,
              let account = try fetchEntity(AccountEntity.self, named: "AccountEntity", id: accountId) else { return }
        account.balance += delta
    }

    /// - Parameter adjustBalance: pass `false` when importing data whose account
    ///   balances already include the transaction.
    func createTransaction(_ transaction: Transaction, adjustBalance: Bool = true) throws {
        let entity = TransactionEntity(context: context)
        entity.id = transaction.id
        entity.amount = transaction.amount
        entity.type = transaction.type.rawValue
        entity.categoryId = transaction.categoryId
        entity.accountId = transaction.accountId
        entity.note = transaction.note
        entity.date = transaction.date
        entity.isRecurring = transaction.isRecurring
        entity.recurringFrequency = transaction.recurringFrequency?.rawValue
        entity.tags = transaction.tags.joined(separator: ",")
        entity.createdAt = transaction.createdAt
        entity.updatedAt = transaction.updatedAt

        if adjustBalance {
            try self.adjustBalance(
                accountId: transaction.accountId,
                by: balanceEffect(type: transaction.type, amount: transaction.amount)
            )
        }
        try saveContext()
    }

    /// - Parameters:
    ///   - from: inclusive lower bound
    ///   - to: exclusive upper bound
    func fetchTransactions(from: Date? = nil, to: Date? = nil) throws -> [Transaction] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        var predicates: [NSPredicate] = []

        if let from = from {
            predicates.append(NSPredicate(format: "date >= %@", from as NSDate))
        }
        if let to = to {
            predicates.append(NSPredicate(format: "date < %@", to as NSDate))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toTransaction() }
    }

    func transactionExists(id: UUID) throws -> Bool {
        try fetchEntity(TransactionEntity.self, named: "TransactionEntity", id: id) != nil
    }

    func updateTransaction(_ transaction: Transaction) throws {
        guard let entity = try fetchEntity(TransactionEntity.self, named: "TransactionEntity", id: transaction.id) else { return }

        // Undo the old effect on the old account, then apply the new one.
        if let oldType = TransactionType(rawValue: entity.type) {
            try adjustBalance(accountId: entity.accountId, by: -balanceEffect(type: oldType, amount: entity.amount))
        }
        try adjustBalance(
            accountId: transaction.accountId,
            by: balanceEffect(type: transaction.type, amount: transaction.amount)
        )

        entity.amount = transaction.amount
        entity.type = transaction.type.rawValue
        entity.categoryId = transaction.categoryId
        entity.accountId = transaction.accountId
        entity.note = transaction.note
        entity.date = transaction.date
        entity.isRecurring = transaction.isRecurring
        entity.recurringFrequency = transaction.recurringFrequency?.rawValue
        entity.tags = transaction.tags.joined(separator: ",")
        entity.updatedAt = Date()
        try saveContext()
    }

    func deleteTransaction(id: UUID) throws {
        guard let entity = try fetchEntity(TransactionEntity.self, named: "TransactionEntity", id: id) else { return }

        if let type = TransactionType(rawValue: entity.type) {
            try adjustBalance(accountId: entity.accountId, by: -balanceEffect(type: type, amount: entity.amount))
        }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Category Operations

    func createCategory(_ category: Category) throws {
        let entity = CategoryEntity(context: context)
        entity.id = category.id
        entity.name = category.name
        entity.icon = category.icon
        entity.color = category.color
        entity.type = category.type.rawValue
        entity.parentId = category.parentId
        entity.budgetLimit = category.budgetLimit ?? 0
        entity.isActive = category.isActive
        entity.sortOrder = Int16(category.sortOrder)
        entity.createdAt = category.createdAt
        try saveContext()
    }

    func fetchCategories(type: CategoryType? = nil) throws -> [Category] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()

        if let type = type {
            request.predicate = NSPredicate(format: "type == %@ OR type == %@", type.rawValue, CategoryType.both.rawValue)
        }

        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toCategory() }
    }

    func categoryExists(id: UUID) throws -> Bool {
        try fetchEntity(CategoryEntity.self, named: "CategoryEntity", id: id) != nil
    }

    func updateCategory(_ category: Category) throws {
        guard let entity = try fetchEntity(CategoryEntity.self, named: "CategoryEntity", id: category.id) else { return }
        entity.name = category.name
        entity.icon = category.icon
        entity.color = category.color
        entity.type = category.type.rawValue
        entity.parentId = category.parentId
        entity.budgetLimit = category.budgetLimit ?? 0
        entity.isActive = category.isActive
        entity.sortOrder = Int16(category.sortOrder)
        try saveContext()
    }

    func deleteCategory(id: UUID) throws {
        guard let entity = try fetchEntity(CategoryEntity.self, named: "CategoryEntity", id: id) else { return }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Account Operations

    func createAccount(_ account: Account) throws {
        let entity = AccountEntity(context: context)
        entity.id = account.id
        entity.name = account.name
        entity.type = account.type.rawValue
        entity.balance = account.balance
        entity.currency = account.currency
        entity.icon = account.icon
        entity.color = account.color
        entity.isActive = account.isActive
        entity.includeInTotal = account.includeInTotal
        entity.createdAt = account.createdAt
        try saveContext()
    }

    func fetchAccounts() throws -> [Account] {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toAccount() }
    }

    func accountExists(id: UUID) throws -> Bool {
        try fetchEntity(AccountEntity.self, named: "AccountEntity", id: id) != nil
    }

    func updateAccount(_ account: Account) throws {
        guard let entity = try fetchEntity(AccountEntity.self, named: "AccountEntity", id: account.id) else { return }
        entity.name = account.name
        entity.type = account.type.rawValue
        entity.balance = account.balance
        entity.currency = account.currency
        entity.icon = account.icon
        entity.color = account.color
        entity.isActive = account.isActive
        entity.includeInTotal = account.includeInTotal
        try saveContext()
    }

    /// Archives the account instead of deleting it so existing transactions stay intact.
    func deleteAccount(id: UUID) throws {
        guard let entity = try fetchEntity(AccountEntity.self, named: "AccountEntity", id: id) else { return }
        entity.isActive = false
        try saveContext()
    }

    // MARK: - Budget Operations

    func createBudget(_ budget: Budget) throws {
        let entity = BudgetEntity(context: context)
        entity.id = budget.id
        entity.categoryId = budget.categoryId
        entity.amount = budget.amount
        entity.period = budget.period.rawValue
        entity.startDate = budget.startDate
        entity.endDate = budget.endDate
        entity.isActive = budget.isActive
        entity.createdAt = budget.createdAt
        try saveContext()
    }

    func fetchBudgets() throws -> [Budget] {
        let request: NSFetchRequest<BudgetEntity> = BudgetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toBudget() }
    }

    func budgetExists(id: UUID) throws -> Bool {
        try fetchEntity(BudgetEntity.self, named: "BudgetEntity", id: id) != nil
    }

    func updateBudget(_ budget: Budget) throws {
        guard let entity = try fetchEntity(BudgetEntity.self, named: "BudgetEntity", id: budget.id) else { return }
        entity.categoryId = budget.categoryId
        entity.amount = budget.amount
        entity.period = budget.period.rawValue
        entity.startDate = budget.startDate
        entity.endDate = budget.endDate
        entity.isActive = budget.isActive
        try saveContext()
    }

    func deleteBudget(id: UUID) throws {
        guard let entity = try fetchEntity(BudgetEntity.self, named: "BudgetEntity", id: id) else { return }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Statistics

    func getTransactionsByCategory(from: Date, to: Date) throws -> [UUID: Double] {
        let transactions = try fetchTransactions(from: from, to: to)
        var categoryTotals: [UUID: Double] = [:]

        for transaction in transactions where transaction.type == .expense {
            categoryTotals[transaction.categoryId, default: 0] += transaction.amount
        }

        return categoryTotals
    }

    func getTotalBalance() throws -> Double {
        let accounts = try fetchAccounts()
        return accounts.filter { $0.includeInTotal }.reduce(0) { $0 + $1.balance }
    }

    func getMonthlyIncome(from: Date, to: Date) throws -> Double {
        let transactions = try fetchTransactions(from: from, to: to)
        return transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    func getMonthlyExpenses(from: Date, to: Date) throws -> Double {
        let transactions = try fetchTransactions(from: from, to: to)
        return transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
}
