import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func scheduleBudgetAlert(categoryName: String, spent: Double, budget: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = "You've spent \(Int((spent/budget) * 100))% of your \(categoryName) budget"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        center.add(request)
    }

    func scheduleRecurringTransactionReminder(transaction: Transaction) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Transaction"
        content.body = "Don't forget: \(transaction.note)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: true)
        let request = UNNotificationRequest(identifier: transaction.id.uuidString, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
