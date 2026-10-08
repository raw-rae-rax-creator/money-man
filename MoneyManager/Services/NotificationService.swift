import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    private var notificationsEnabled: Bool {
        AppSettings.load().notificationEnabled
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func scheduleBudgetAlert(categoryName: String, spent: Double, budget: Double) {
        guard notificationsEnabled, budget > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = "You've spent \(Int((spent/budget) * 100))% of your \(categoryName) budget"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Debts

    private func debtIdentifier(_ id: UUID) -> String { "debt-\(id.uuidString)" }

    func scheduleDebtReminder(for debt: Debt) {
        cancelDebtReminder(id: debt.id)
        guard notificationsEnabled,
              debt.reminderEnabled,
              debt.status == .active,
              let dueDate = debt.expectedReturnDate else { return }

        let amount = debt.remainingAmount.formattedAsCurrency()
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch debt.type {
        case .given:
            content.title = "Debt reminder"
            content.body = "\(debt.personName) should return \(amount) by \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        case .received:
            content.title = "Time to pay back"
            content.body = "You owe \(debt.personName) \(amount) by \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }

        schedule(
            identifier: debtIdentifier(debt.id),
            content: content,
            dueDate: dueDate,
            daysBefore: debt.reminderDaysBefore
        )
    }

    func cancelDebtReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [debtIdentifier(id)])
    }

    // MARK: - Bills

    private func billIdentifier(_ id: UUID) -> String { "bill-\(id.uuidString)" }

    func scheduleBillReminder(for bill: Bill) {
        cancelBillReminder(id: bill.id)
        guard notificationsEnabled, !bill.isPaid else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bill due soon"
        content.body = "\(bill.name): \(bill.amount.formattedAsCurrency()) due \(bill.dueDate.formatted(date: .abbreviated, time: .omitted))"
        content.sound = .default

        schedule(
            identifier: billIdentifier(bill.id),
            content: content,
            dueDate: bill.dueDate,
            daysBefore: bill.reminderDaysBefore
        )
    }

    func cancelBillReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [billIdentifier(id)])
    }

    // MARK: - Helpers

    /// Fires at 10:00 `daysBefore` days before `dueDate`. If that moment has passed
    /// but the due date hasn't, fires in a minute instead.
    private func schedule(identifier: String, content: UNMutableNotificationContent, dueDate: Date, daysBefore: Int) {
        let calendar = Calendar.current
        guard let remindDay = calendar.date(byAdding: .day, value: -daysBefore, to: dueDate) else { return }
        var components = calendar.dateComponents([.year, .month, .day], from: remindDay)
        components.hour = 10
        components.minute = 0

        let trigger: UNNotificationTrigger
        if let fireDate = calendar.date(from: components), fireDate > Date() {
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else if calendar.startOfDay(for: dueDate) >= calendar.startOfDay(for: Date()) {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        } else {
            return
        }

        Task {
            guard await requestPermission() else { return }
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
