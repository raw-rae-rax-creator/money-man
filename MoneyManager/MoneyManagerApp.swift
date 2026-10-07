import SwiftUI

@main
struct MoneyManagerApp: App {
    @StateObject private var securityManager = SecurityManager()

    var body: some Scene {
        WindowGroup {
            if securityManager.isAuthenticated {
                ContentView()
                    .environmentObject(securityManager)
            } else {
                LockScreenView()
                    .environmentObject(securityManager)
            }
        }
    }
}

class SecurityManager: ObservableObject {
    @Published var isAuthenticated: Bool = true
    @Published var isAppLocked: Bool = false

    private let security = SecurityService.shared
    private let settingsKey = "appSettings"

    func authenticate() async {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            isAuthenticated = true
            return
        }

        if settings.biometricEnabled {
            let success = await security.authenticateWithBiometrics()
            isAuthenticated = success
        } else if settings.passcodeEnabled {
            isAppLocked = true
            isAuthenticated = false
        } else {
            isAuthenticated = true
        }
    }

    func unlock() {
        isAuthenticated = true
        isAppLocked = false
    }
}
