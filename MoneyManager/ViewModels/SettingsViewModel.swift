import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var isBiometricAvailable: Bool = false
    @Published var biometricType: String = "Biometrics"
    @Published var showPasscodeSetup: Bool = false
    @Published var exportURL: URL?
    @Published var importResult: ImportResult?
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showSuccess: Bool = false
    @Published var successMessage: String = ""

    private let security = SecurityService.shared
    private let importExport = ImportExportService()

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "appSettings"),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }

        isBiometricAvailable = security.isBiometricAvailable()
        let bioType = security.getBiometricType()
        switch bioType {
        case .faceID:
            biometricType = "Face ID"
        case .touchID:
            biometricType = "Touch ID"
        default:
            biometricType = "Biometrics"
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "appSettings")
        }
    }

    func toggleBiometric() async {
        if settings.biometricEnabled {
            settings.biometricEnabled = false
        } else {
            let success = await security.authenticateWithBiometrics()
            if success {
                settings.biometricEnabled = true
            }
        }
        saveSettings()
    }

    func exportData(format: ExportFormat) {
        do {
            switch format {
            case .csv:
                exportURL = try importExport.exportToCSV()
            case .json:
                exportURL = try importExport.exportToJSON()
            }
            showSuccess = true
            successMessage = "Data exported successfully"
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func importData(from url: URL) {
        do {
            let result: ImportResult
            if url.pathExtension == "csv" {
                let count = try importExport.importFromCSV(url: url)
                result = ImportResult(transactionsImported: count)
            } else {
                result = try importExport.importFromJSON(url: url)
            }
            importResult = result
            showSuccess = true
            successMessage = "Imported \(result.totalImported) items successfully"
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func createBackup() {
        do {
            exportURL = try importExport.createBackup()
            showSuccess = true
            successMessage = "Backup created successfully"
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
