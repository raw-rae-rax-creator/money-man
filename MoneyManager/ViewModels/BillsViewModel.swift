import Foundation
import SwiftUI

@MainActor
class BillsViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var subscriptions: [Subscription] = []
    @Published var isLoading: Bool = false
    @Published var showAddBillSheet: Bool = false
    @Published var showAddSubscriptionSheet: Bool = false

    @Published var billName: String = ""
    @Published var billAmount: String = ""
    @Published var billDueDate: Date = Date()
    @Published var billIsRecurring: Bool = false
    @Published var billFrequency: RecurringFrequency = .monthly
    @Published var billReminderDays: Int = 3

    @Published var subscriptionName: String = ""
    @Published var subscriptionAmount: String = ""
    @Published var subscriptionCycle: BillingCycle = .monthly
    @Published var subscriptionNextDate: Date = Date()

    private let billsKey = ImportExportService.billsKey
    private let subscriptionsKey = ImportExportService.subscriptionsKey
    private let notifications = NotificationService.shared

    func loadData() {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: billsKey),
           let decoded = try? JSONDecoder().decode([Bill].self, from: data) {
            bills = decoded.sorted { $0.dueDate < $1.dueDate }
        }

        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
            subscriptions = decoded
        }

        rollSubscriptionsForward()
        subscriptions.sort { $0.nextBillingDate < $1.nextBillingDate }
    }

    /// Moves past billing dates to the next upcoming one.
    private func rollSubscriptionsForward() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var changed = false

        for index in subscriptions.indices {
            let step = subscriptions[index].billingCycle.dateComponent
            var next = subscriptions[index].nextBillingDate
            var iterations = 0
            while calendar.startOfDay(for: next) < today && iterations < 1000 {
                guard let advanced = calendar.date(byAdding: step, to: next) else { break }
                next = advanced
                iterations += 1
            }
            if next != subscriptions[index].nextBillingDate {
                subscriptions[index].nextBillingDate = next
                changed = true
            }
        }

        if changed { saveData() }
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(encoded, forKey: billsKey)
        }
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }

    var isBillFormValid: Bool {
        guard let amount = AppCurrency.parseAmount(billAmount), amount > 0 else { return false }
        return !billName.trimmed.isEmpty
    }

    var isSubscriptionFormValid: Bool {
        guard let amount = AppCurrency.parseAmount(subscriptionAmount), amount > 0 else { return false }
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
            reminderDaysBefore: billReminderDays
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
            nextBillingDate: subscriptionNextDate
        )

        subscriptions.append(subscription)
        rollSubscriptionsForward()
        subscriptions.sort { $0.nextBillingDate < $1.nextBillingDate }
        saveData()
        Haptics.success()
        resetSubscriptionForm()
    }

    func markBillAsPaid(_ bill: Bill) {
        guard let index = bills.firstIndex(where: { $0.id == bill.id }) else { return }

        // A recurring bill moves to its next due date instead of disappearing.
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
        saveData()
        Haptics.success()
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
        showAddBillSheet = false
    }

    func resetSubscriptionForm() {
        subscriptionName = ""
        subscriptionAmount = ""
        subscriptionCycle = .monthly
        subscriptionNextDate = Date()
        showAddSubscriptionSheet = false
    }

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
        return bills.filter { !$0.isPaid && $0.dueDate < endOfMonth }.reduce(0) { $0 + $1.amount }
    }
}
