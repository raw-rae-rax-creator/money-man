import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var isBiometricAvailable: Bool = false
    @Published var biometricType: String = "Biometrics".localized
    @Published var showPasscodeSetup: Bool = false
    @Published var exportURL: URL?
    @Published var importResult: ImportResult?
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showSuccess: Bool = false
    @Published var successMessage: String = ""

    private let security = SecurityService.shared
    private let importExport = ImportExportService()

    var biometricIcon: String {
        biometricType == "Touch ID" ? "touchid" : "faceid"
    }

    func loadSettings() {
        settings = AppSettings.load()

        // Passcode flag without a stored passcode would mean a lock screen nobody can pass.
        if settings.passcodeEnabled && security.loadPasscode() == nil {
            settings.passcodeEnabled = false
            saveSettings()
        }

        isBiometricAvailable = security.isBiometricAvailable()
        let bioType = security.getBiometricType()
        switch bioType {
        case .faceID:
            biometricType = "Face ID"
        case .touchID:
            biometricType = "Touch ID"
        default:
            biometricType = "Biometrics".localized
        }
    }

    func saveSettings() {
        settings.save()
    }

    func setBiometric(_ enabled: Bool) async {
        if enabled {
            // Confirm the user can actually authenticate before turning the lock on.
            guard await security.authenticateWithBiometrics(reason: "Enable %@ for moneai".localizedFormat(biometricType)) else { return }
        }
        settings.biometricEnabled = enabled
        saveSettings()
    }

    func setPasscode(_ passcode: String) -> Bool {
        do {
            try security.savePasscode(passcode)
            settings.passcodeEnabled = true
            saveSettings()
            return true
        } catch {
            errorMessage = "Could not save passcode".localized
            showError = true
            return false
        }
    }

    func disablePasscode() {
        security.deletePasscode()
        settings.passcodeEnabled = false
        saveSettings()
    }

    func setNotifications(_ enabled: Bool) {
        settings.notificationEnabled = enabled
        saveSettings()
        if enabled {
            Task { _ = await NotificationService.shared.requestPermission() }
        } else {
            NotificationService.shared.cancelAllNotifications()
        }
    }

    func exportData(format: ExportFormat) {
        do {
            switch format {
            case .csv:
                exportURL = try importExport.exportToCSV()
            case .json:
                exportURL = try importExport.exportToJSON()
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func importData(from url: URL) {
        do {
            let result: ImportResult
            if url.pathExtension.lowercased() == "csv" {
                let count = try importExport.importFromCSV(url: url)
                result = ImportResult(transactionsImported: count)
            } else {
                result = try importExport.importFromJSON(url: url)
            }
            importResult = result
            showSuccess = true
            successMessage = "Imported %lld items".localizedFormat(result.totalImported)
            if !result.errors.isEmpty {
                successMessage += "\n" + "%lld items failed".localizedFormat(result.errors.count)
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func createBackup() {
        do {
            exportURL = try importExport.createBackup()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}

enum ExportFormat {
    case csv
    case json
}
