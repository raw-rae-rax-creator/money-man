import SwiftUI

@main
struct MoneyManagerApp: App {
    @StateObject private var securityManager = SecurityManager()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue

    init() {
        DatabaseService.shared.seedDefaultsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isAuthenticated {
                    ContentView()
                } else {
                    LockScreenView()
                }
            }
            .environmentObject(securityManager)
            .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                securityManager.lock()
            }
        }
    }
}

class SecurityManager: ObservableObject {
    @Published var isAuthenticated: Bool

    init() {
        isAuthenticated = !SecurityManager.isLockEnabled
    }

    static var isLockEnabled: Bool {
        let settings = AppSettings.load()
        let hasPasscode = settings.passcodeEnabled && SecurityService.shared.loadPasscode() != nil
        return settings.biometricEnabled || hasPasscode
    }

    func lock() {
        if SecurityManager.isLockEnabled {
            isAuthenticated = false
        }
    }

    func unlock() {
        isAuthenticated = true
    }
}
