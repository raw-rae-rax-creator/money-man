import SwiftUI

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

    static let storageKey = "appSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: AppSettings.storageKey)
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    static let storageKey = "appTheme"

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
