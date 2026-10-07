import Foundation

struct AppSettings: Codable {
    var currency: String
    var firstDayOfWeek: Int
    var monthStartDay: Int
    var biometricEnabled: Bool
    var passcodeEnabled: Bool
    var passcode: String?
    var theme: AppTheme
    var language: String
    var dateFormat: String
    var notificationEnabled: Bool

    init() {
        self.currency = "USD"
        self.firstDayOfWeek = 1
        self.monthStartDay = 1
        self.biometricEnabled = false
        self.passcodeEnabled = false
        self.passcode = nil
        self.theme = .system
        self.language = "en"
        self.dateFormat = "MM/dd/yyyy"
        self.notificationEnabled = true
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}
