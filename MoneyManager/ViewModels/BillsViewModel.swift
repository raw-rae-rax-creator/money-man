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

    private let billsKey = "bills"
    private let subscriptionsKey = "subscriptions"

    func loadData() {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: billsKey),
           let decoded = try? JSONDecoder().decode([Bill].self, from: data) {
            bills = decoded.sorted { $0.dueDate < $1.dueDate }
        }

        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([Subscription].self, from: data) {
            subscriptions = decoded.sorted { $0.nextBillingDate < $1.nextBillingDate }
        }
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(bills) {
            UserDefaults.standard.set(encoded, forKey: billsKey)
        }
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }

    func addBill() {
        guard let amount = Double(billAmount), amount > 0 else { return }
        guard !billName.isEmpty else { return }

        let bill = Bill(
            name: billName,
            amount: amount,
            dueDate: billDueDate,
            recurringFrequency: billIsRecurring ? billFrequency : nil,
            isRecurring: billIsRecurring,
            reminderDaysBefore: billReminderDays
        )

        bills.append(bill)
        saveData()
        resetBillForm()
    }

    func addSubscription() {
        guard let amount = Double(subscriptionAmount), amount > 0 else { return }
        guard !subscriptionName.isEmpty else { return }

        let subscription = Subscription(
            name: subscriptionName,
            amount: amount,
            billingCycle: subscriptionCycle,
            nextBillingDate: subscriptionNextDate
        )

        subscriptions.append(subscription)
        saveData()
        resetSubscriptionForm()
    }

    func markBillAsPaid(_ bill: Bill) {
        guard let index = bills.firstIndex(where: { $0.id == bill.id }) else { return }
        bills[index].isPaid = true
        saveData()
    }

    func deleteBill(_ bill: Bill) {
        bills.removeAll { $0.id == bill.id }
        saveData()
    }

    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveData()
    }

    private func resetBillForm() {
        billName = ""
        billAmount = ""
        billDueDate = Date()
        billIsRecurring = false
        billFrequency = .monthly
        billReminderDays = 3
        showAddBillSheet = false
    }

    private func resetSubscriptionForm() {
        subscriptionName = ""
        subscriptionAmount = ""
        subscriptionCycle = .monthly
        subscriptionNextDate = Date()
        showAddSubscriptionSheet = false
    }

    var upcomingBills: [Bill] {
        bills.filter { !$0.isPaid && $0.daysUntilDue >= 0 }.prefix(5).map { $0 }
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
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: now.startOfMonth())!

        return bills.filter { !$0.isPaid && $0.dueDate <= endOfMonth }.reduce(0) { $0 + $1.amount }
    }
}
