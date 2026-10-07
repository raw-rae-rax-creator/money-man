import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showExportOptions = false
    @State private var showImportPicker = false

    var body: some View {
        NavigationView {
            List {
                securitySection
                preferencesSection
                dataManagementSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadSettings()
            }
            .sheet(isPresented: $showExportOptions) {
                ExportOptionsView(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json, .commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.importData(from: url)
                    }
                case .failure(let error):
                    viewModel.showError = true
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(item: $viewModel.exportURL) { url in
                ShareSheet(items: [url])
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            if viewModel.isBiometricAvailable {
                Toggle("Enable \(viewModel.biometricType)", isOn: $viewModel.settings.biometricEnabled)
                    .onChange(of: viewModel.settings.biometricEnabled) { _ in
                        Task {
                            await viewModel.toggleBiometric()
                        }
                    }
            }

            Toggle("Enable Passcode", isOn: $viewModel.settings.passcodeEnabled)
                .onChange(of: viewModel.settings.passcodeEnabled) { newValue in
                    if newValue {
                        viewModel.showPasscodeSetup = true
                    }
                    viewModel.saveSettings()
                }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Currency", selection: $viewModel.settings.currency) {
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
                Text("RUB (₽)").tag("RUB")
            }
            .onChange(of: viewModel.settings.currency) { _ in
                viewModel.saveSettings()
            }

            Picker("Theme", selection: $viewModel.settings.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme)
                }
            }
            .onChange(of: viewModel.settings.theme) { _ in
                viewModel.saveSettings()
            }

            Toggle("Notifications", isOn: $viewModel.settings.notificationEnabled)
                .onChange(of: viewModel.settings.notificationEnabled) { _ in
                    viewModel.saveSettings()
                }
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
            Button(action: { showExportOptions = true }) {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            Button(action: { showImportPicker = true }) {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }

            Button(action: { viewModel.createBackup() }) {
                Label("Create Backup", systemImage: "externaldrive.fill")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            NavigationLink("Privacy Policy") {
                Text("Money Manager stores all data locally on your device. No data is collected, transmitted, or shared. Your financial information never leaves your device.")
                    .padding()
            }

            NavigationLink("Terms of Service") {
                Text("This app is provided as-is for personal use. All data is stored locally and is your responsibility to backup.")
                    .padding()
            }
        }
    }
}

struct ExportOptionsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    viewModel.exportData(format: .csv)
                    dismiss()
                }) {
                    Label("Export as CSV", systemImage: "doc.text")
                }

                Button(action: {
                    viewModel.exportData(format: .json)
                    dismiss()
                }) {
                    Label("Export as JSON", systemImage: "doc.zipper")
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String {
        self.absoluteString
    }
}

#Preview {
    SettingsView()
}
