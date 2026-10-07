import Foundation
import CoreData

class DatabaseService {
    static let shared = DatabaseService()
    private let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "MoneyManagerModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext {
        return container.viewContext
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Transaction Operations

    func createTransaction(_ transaction: Transaction) throws {
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
        saveContext()
    }

    func fetchTransactions(from: Date? = nil, to: Date? = nil) throws -> [Transaction] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        var predicates: [NSPredicate] = []

        if let from = from {
            predicates.append(NSPredicate(format: "date >= %@", from as NSDate))
        }
        if let to = to {
            predicates.append(NSPredicate(format: "date <= %@", to as NSDate))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toTransaction() }
    }

    func updateTransaction(_ transaction: Transaction) throws {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)

        if let entity = try context.fetch(request).first {
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
            saveContext()
        }
    }

    func deleteTransaction(id: UUID) throws {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            saveContext()
        }
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
        saveContext()
    }

    func fetchCategories(type: CategoryType? = nil) throws -> [Category] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()

        if let type = type {
            request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        }

        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toCategory() }
    }

    func updateCategory(_ category: Category) throws {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)

        if let entity = try context.fetch(request).first {
            entity.name = category.name
            entity.icon = category.icon
            entity.color = category.color
            entity.type = category.type.rawValue
            entity.parentId = category.parentId
            entity.budgetLimit = category.budgetLimit ?? 0
            entity.isActive = category.isActive
            entity.sortOrder = Int16(category.sortOrder)
            saveContext()
        }
    }

    func deleteCategory(id: UUID) throws {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            saveContext()
        }
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
        saveContext()
    }

    func fetchAccounts() throws -> [Account] {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toAccount() }
    }

    func updateAccount(_ account: Account) throws {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", account.id as CVarArg)

        if let entity = try context.fetch(request).first {
            entity.name = account.name
            entity.type = account.type.rawValue
            entity.balance = account.balance
            entity.currency = account.currency
            entity.icon = account.icon
            entity.color = account.color
            entity.isActive = account.isActive
            entity.includeInTotal = account.includeInTotal
            saveContext()
        }
    }

    func deleteAccount(id: UUID) throws {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            saveContext()
        }
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
        saveContext()
    }

    func fetchBudgets() throws -> [Budget] {
        let request: NSFetchRequest<BudgetEntity> = BudgetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]

        let entities = try context.fetch(request)
        return entities.compactMap { $0.toBudget() }
    }

    func updateBudget(_ budget: Budget) throws {
        let request: NSFetchRequest<BudgetEntity> = BudgetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", budget.id as CVarArg)

        if let entity = try context.fetch(request).first {
            entity.categoryId = budget.categoryId
            entity.amount = budget.amount
            entity.period = budget.period.rawValue
            entity.startDate = budget.startDate
            entity.endDate = budget.endDate
            entity.isActive = budget.isActive
            saveContext()
        }
    }

    func deleteBudget(id: UUID) throws {
        let request: NSFetchRequest<BudgetEntity> = BudgetEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            saveContext()
        }
    }

    // MARK: - Statistics

    func getTransactionsByCategory(from: Date, to: Date) throws -> [UUID: Double] {
        let transactions = try fetchTransactions(from: from, to: to)
        var categoryTotals: [UUID: Double] = [:]

        for transaction in transactions {
            if transaction.type == .expense {
                categoryTotals[transaction.categoryId, default: 0] += transaction.amount
            }
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
