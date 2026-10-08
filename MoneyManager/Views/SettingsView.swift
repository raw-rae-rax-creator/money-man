import SwiftUI
import UniformTypeIdentifiers

/// The "More" tab: secondary finance screens plus settings.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage(AppCurrency.storageKey) private var currencyCode: String = AppCurrency.defaultCode
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue
    @State private var showExportOptions = false
    @State private var showImportPicker = false

    var body: some View {
        NavigationView {
            List {
                financeSection
                preferencesSection
                securitySection
                dataManagementSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .onAppear {
                viewModel.loadSettings()
            }
            .confirmationDialog("Export Data", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("CSV (transactions)") {
                    viewModel.exportData(format: .csv)
                }
                Button("JSON (everything)") {
                    viewModel.exportData(format: .json)
                }
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
            .alert("Done", isPresented: $viewModel.showSuccess) {
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
            .sheet(isPresented: $viewModel.showPasscodeSetup) {
                PasscodeSetupView { passcode in
                    viewModel.setPasscode(passcode)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var financeSection: some View {
        Section("Finance") {
            NavigationLink(destination: AccountsView()) {
                SettingsRow(title: "Accounts", icon: "creditcard.fill", color: .blue)
            }
            NavigationLink(destination: CategoryListView()) {
                SettingsRow(title: "Categories", icon: "square.grid.2x2.fill", color: .orange)
            }
            NavigationLink(destination: BudgetView()) {
                SettingsRow(title: "Budgets", icon: "chart.bar.fill", color: .green)
            }
            NavigationLink(destination: GoalsView()) {
                SettingsRow(title: "Savings Goals", icon: "target", color: .purple)
            }
            NavigationLink(destination: BillsView()) {
                SettingsRow(title: "Bills & Subscriptions", icon: "doc.text.fill", color: .red)
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker(selection: $currencyCode) {
                ForEach(AppCurrency.all) { currency in
                    Text("\(currency.code) (\(currency.symbol)) — \(currency.name)").tag(currency.code)
                }
            } label: {
                SettingsRow(title: "Currency", icon: "banknote.fill", color: .green)
            }

            Picker(selection: $themeRaw) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue.capitalized).tag(theme.rawValue)
                }
            } label: {
                SettingsRow(title: "Theme", icon: "circle.lefthalf.filled", color: .indigo)
            }

            Toggle(isOn: Binding(
                get: { viewModel.settings.notificationEnabled },
                set: { viewModel.setNotifications($0) }
            )) {
                SettingsRow(title: "Reminders", icon: "bell.badge.fill", color: .red)
            }
        }
    }

    private var securitySection: some View {
        Section {
            if viewModel.isBiometricAvailable {
                Toggle(isOn: Binding(
                    get: { viewModel.settings.biometricEnabled },
                    set: { newValue in
                        Task { await viewModel.setBiometric(newValue) }
                    }
                )) {
                    SettingsRow(title: viewModel.biometricType, icon: viewModel.biometricIcon, color: .green)
                }
            }

            Toggle(isOn: Binding(
                get: { viewModel.settings.passcodeEnabled },
                set: { newValue in
                    if newValue {
                        viewModel.showPasscodeSetup = true
                    } else {
                        viewModel.disablePasscode()
                    }
                }
            )) {
                SettingsRow(title: "Passcode", icon: "lock.fill", color: .gray)
            }
        } header: {
            Text("Security")
        } footer: {
            Text("The app locks when it goes to the background.")
        }
    }

    private var dataManagementSection: some View {
        Section {
            Button(action: { showExportOptions = true }) {
                SettingsRow(title: "Export Data", icon: "square.and.arrow.up", color: .blue)
            }

            Button(action: { showImportPicker = true }) {
                SettingsRow(title: "Import Data", icon: "square.and.arrow.down", color: .blue)
            }

            Button(action: { viewModel.createBackup() }) {
                SettingsRow(title: "Create Backup", icon: "externaldrive.fill", color: .teal)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("A JSON backup includes accounts, transactions, debts, goals and bills. Restore it with Import.")
        }
        .foregroundColor(.primary)
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }

            NavigationLink("Privacy Policy") {
                ScrollView {
                    Text("Money Manager stores all data locally on your device. No data is collected, transmitted, or shared. Your financial information never leaves your device.")
                        .padding()
                }
                .navigationTitle("Privacy")
            }

            NavigationLink("Terms of Service") {
                ScrollView {
                    Text("This app is provided as-is for personal use. All data is stored locally and is your responsibility to backup.")
                        .padding()
                }
                .navigationTitle("Terms")
            }
        }
    }
}

/// iOS Settings-style row with a colored rounded icon.
struct SettingsRow: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 29, height: 29)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
        }
    }
}

struct PasscodeSetupView: View {
    let onSave: (String) -> Bool
    @Environment(\.dismiss) var dismiss
    @State private var passcode = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case passcode, confirmation
    }

    private var isValid: Bool {
        (4...8).contains(passcode.count) && passcode.allSatisfy(\.isNumber) && passcode == confirmation
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("New passcode", text: $passcode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .passcode)
                    SecureField("Repeat passcode", text: $confirmation)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .confirmation)
                } footer: {
                    if !confirmation.isEmpty && passcode != confirmation {
                        Text("Passcodes don't match")
                            .foregroundColor(.red)
                    } else {
                        Text("4–8 digits.")
                    }
                }
            }
            .navigationTitle("Set Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(passcode) {
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { focusedField = .passcode }
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
