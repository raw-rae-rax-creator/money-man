import Foundation
import SwiftUI

@MainActor
class BillsViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var subscriptions: [Subscription] = []
    @Published var isLoading: Bool = false
    @Published var showAddBillSheet: Bool = false
    @Published var showAddSubscriptionSheet: Bool = false

    /// Set to open the payment sheet.
    @Published var paymentRequest: PaymentRequest?
    @Published var accounts: [Account] = []
    @Published var expenseCategories: [Category] = []

    @Published var billName: String = ""
    @Published var billAmount: String = ""
    @Published var billDueDate: Date = Date()
    @Published var billIsRecurring: Bool = false
    @Published var billFrequency: RecurringFrequency = .monthly
    @Published var billReminderDays: Int = 3
    @Published var billHasForeignPrice: Bool = false
    @Published var billForeignCurrency: String = "USD"
    @Published var billForeignAmount: String = ""

    @Published var subscriptionName: String = ""
    @Published var subscriptionAmount: String = ""
    @Published var subscriptionCycle: BillingCycle = .monthly
    @Published var subscriptionNextDate: Date = Date()
    @Published var subscriptionHasForeignPrice: Bool = false
    @Published var subscriptionForeignCurrency: String = "USD"
    @Published var subscriptionForeignAmount: String = ""

    private let billsKey = ImportExportService.billsKey
    private let subscriptionsKey = ImportExportService.subscriptionsKey
    private let notifications = NotificationService.shared
    private let database = DatabaseService.shared

    func loadData() {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: billsKey),
           let decoded = try? JSONDecoder().decode([Bill].self, from: data) {
            bills = decoded.sorted { $0.dueDate < $1.dueDate }
        }

        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
            // Billing dates no longer roll forward by themselves: a due subscription
            // waits until it's paid (or skipped), so no charge goes unrecorded.
            subscriptions = decoded.sorted { $0.nextBillingDate < $1.nextBillingDate }
        }

        accounts = (try? database.fetchAccounts()) ?? []
        expenseCategories = (try? database.fetchCategories(type: .expense)) ?? []
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(encoded, forKey: billsKey)
        }
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }

    /// Currencies that can be used for a foreign price (everything except the app currency).
    var foreignCurrencies: [CurrencyInfo] {
        AppCurrency.all.filter { $0.code != AppCurrency.code }
    }

    /// "Bills & Utilities" when it exists, otherwise the first expense category.
    var defaultCategoryId: UUID? {
        expenseCategories.first { $0.name == "Bills & Utilities" }?.id ?? expenseCategories.first?.id
    }

    // MARK: - Forms

    var isBillFormValid: Bool {
        guard let amount = AppCurrency.parseAmount(billAmount), amount > 0 else { return false }
        if billHasForeignPrice {
            guard let foreign = AppCurrency.parseAmount(billForeignAmount), foreign > 0 else { return false }
        }
        return !billName.trimmed.isEmpty
    }

    var isSubscriptionFormValid: Bool {
        guard let amount = AppCurrency.parseAmount(subscriptionAmount), amount > 0 else { return false }
        if subscriptionHasForeignPrice {
            guard let foreign = AppCurrency.parseAmount(subscriptionForeignAmount), foreign > 0 else { return false }
        }
        return !subscriptionName.trimmed.isEmpty
    }

    func addBill() {
        guard isBillFormValid, let amount = AppCurrency.parseAmount(billAmount) else { return }

        let bill = Bill(
            name: billName.trimmed,
            amount: amount,
            dueDate: billDueDate,
            recurringFrequency: billIsRecurring ? billFrequency : nil,
            isRecurring: billIsRecurring,
            reminderDaysBefore: billReminderDays,
            foreignAmount: billHasForeignPrice ? AppCurrency.parseAmount(billForeignAmount) : nil,
            foreignCurrency: billHasForeignPrice ? billForeignCurrency : nil
        )

        bills.append(bill)
        bills.sort { $0.dueDate < $1.dueDate }
        saveData()
        notifications.scheduleBillReminder(for: bill)
        Haptics.success()
        resetBillForm()
    }

    func addSubscription() {
        guard isSubscriptionFormValid, let amount = AppCurrency.parseAmount(subscriptionAmount) else { return }

        let subscription = Subscription(
            name: subscriptionName.trimmed,
            amount: amount,
            billingCycle: subscriptionCycle,
            nextBillingDate: subscriptionNextDate,
            foreignAmount: subscriptionHasForeignPrice ? AppCurrency.parseAmount(subscriptionForeignAmount) : nil,
            foreignCurrency: subscriptionHasForeignPrice ? subscriptionForeignCurrency : nil
        )

        subscriptions.append(subscription)
        subscriptions.sort { $0.nextBillingDate < $1.nextBillingDate }
        saveData()
        Haptics.success()
        resetSubscriptionForm()
    }

    // MARK: - Payments

    func requestPayment(for bill: Bill) {
        paymentRequest = PaymentRequest(bill: bill)
    }

    func requestPayment(for subscription: Subscription) {
        paymentRequest = PaymentRequest(subscription: subscription)
    }

    /// Records the payment as an expense (when an account is chosen), remembers the
    /// amount / exchange rate / account / category for next time, and moves the item on.
    func completePayment(_ request: PaymentRequest, _ result: PaymentResult) {
        if let accountId = result.accountId, let categoryId = result.categoryId {
            let transaction = Transaction(
                amount: result.amount,
                type: .expense,
                categoryId: categoryId,
                accountId: accountId,
                note: request.name,
                date: result.date
            )
            do {
                try database.createTransaction(transaction)
            } catch {
                print("Error recording payment: \(error)")
                return
            }
        }

        let rate: Double? = request.foreignAmount.flatMap { $0 > 0 ? result.amount / $0 : nil }

        switch request.source {
        case .bill:
            guard let index = bills.firstIndex(where: { $0.id == request.id }) else { break }
            bills[index].lastPaidAt = result.date
            bills[index].lastPaidAmount = result.amount
            bills[index].accountId = result.accountId ?? bills[index].accountId
            bills[index].categoryId = result.categoryId ?? bills[index].categoryId
            if let rate = rate { bills[index].lastRate = rate }
            if result.rememberAmount { bills[index].amount = result.amount }
            advanceBill(at: index)

        case .subscription:
            guard let index = subscriptions.firstIndex(where: { $0.id == request.id }) else { break }
            subscriptions[index].lastPaidAt = result.date
            subscriptions[index].lastPaidAmount = result.amount
            subscriptions[index].accountId = result.accountId ?? subscriptions[index].accountId
            subscriptions[index].categoryId = result.categoryId ?? subscriptions[index].categoryId
            if let rate = rate { subscriptions[index].lastRate = rate }
            if result.rememberAmount { subscriptions[index].amount = result.amount }
            advanceSubscription(at: index)
        }

        saveData()
        Haptics.success()
    }

    /// Recurring bills move to the next due date; one-off bills become paid.
    private func advanceBill(at index: Int) {
        let bill = bills[index]
        if bill.isRecurring,
           let frequency = bill.recurringFrequency,
           let nextDate = Calendar.current.date(byAdding: frequency.dateComponent, to: bill.dueDate) {
            bills[index].dueDate = nextDate
            bills[index].isPaid = false
            notifications.scheduleBillReminder(for: bills[index])
        } else {
            bills[index].isPaid = true
            notifications.cancelBillReminder(id: bill.id)
        }
        bills.sort { $0.dueDate < $1.dueDate }
    }

    private func advanceSubscription(at index: Int) {
        let subscription = subscriptions[index]
        if let next = Calendar.current.date(byAdding: subscription.billingCycle.dateComponent, to: subscription.nextBillingDate) {
            subscriptions[index].nextBillingDate = next
        }
        subscriptions.sort { $0.nextBillingDate < $1.nextBillingDate }
    }

    /// Moves a subscription to its next billing date without recording a payment.
    func skip(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        advanceSubscription(at: index)
        saveData()
    }

    func deleteBill(_ bill: Bill) {
        bills.removeAll { $0.id == bill.id }
        saveData()
        notifications.cancelBillReminder(id: bill.id)
    }

    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveData()
    }

    func resetBillForm() {
        billName = ""
        billAmount = ""
        billDueDate = Date()
        billIsRecurring = false
        billFrequency = .monthly
        billReminderDays = 3
        billHasForeignPrice = false
        billForeignCurrency = foreignCurrencies.first { $0.code == "USD" }?.code ?? foreignCurrencies.first?.code ?? "USD"
        billForeignAmount = ""
        showAddBillSheet = false
    }

    func resetSubscriptionForm() {
        subscriptionName = ""
        subscriptionAmount = ""
        subscriptionCycle = .monthly
        subscriptionNextDate = Date()
        subscriptionHasForeignPrice = false
        subscriptionForeignCurrency = foreignCurrencies.first { $0.code == "USD" }?.code ?? foreignCurrencies.first?.code ?? "USD"
        subscriptionForeignAmount = ""
        showAddSubscriptionSheet = false
    }

    // MARK: - Lists & totals

    var upcomingBills: [Bill] {
        bills.filter { !$0.isPaid && !$0.isOverdue }
    }

    var overdueBills: [Bill] {
        bills.filter { $0.isOverdue }
    }

    var totalMonthlySubscriptions: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var totalYearlySubscriptions: Double {
        subscriptions.reduce(0) { $0 + $1.yearlyCost }
    }

    var totalDueThisMonth: Double {
        let endOfMonth = Date().interval(of: .month).end
        let billsDue = bills.filter { !$0.isPaid && $0.dueDate < endOfMonth }.reduce(0) { $0 + $1.amount }
        let subscriptionsDue = subscriptions.filter { $0.nextBillingDate < endOfMonth }.reduce(0) { $0 + $1.amount }
        return billsDue + subscriptionsDue
    }
}
