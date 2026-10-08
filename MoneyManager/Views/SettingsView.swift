import SwiftUI
import UniformTypeIdentifiers

/// The "More" tab: secondary finance screens plus settings.
struct SettingsView: View {
    @EnvironmentObject var router: TabRouter
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage(AppCurrency.storageKey) private var currencyCode: String = AppCurrency.defaultCode
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage(AppPreferences.showCategoryIconsKey) private var showCategoryIcons = true
    @AppStorage(AppPreferences.categoryPickerStyleKey) private var pickerStyleRaw = CategoryPickerStyle.carousel.rawValue
    @AppStorage(AppPreferences.saveLocationKey) private var saveLocation = false
    @State private var showExportOptions = false
    @State private var showImportPicker = false
    @State private var showLocationDenied = false

    var body: some View {
        NavigationView {
            List {
                financeSection
                appearanceSection
                transactionsSection
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
            .alert("Location Access Is Off", isPresented: $showLocationDenied) {
                Button("Open Settings") { openAppSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow location access for moneai in Settings to save where transactions were made.")
            }
            .sheet(isPresented: $viewModel.showPasscodeSetup) {
                PasscodeSetupView { passcode in
                    viewModel.setPasscode(passcode)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// Every screen that isn't in the tab bar is reachable from here.
    private var financeSection: some View {
        Section {
            ForEach(router.hiddenScreens) { screen in
                NavigationLink(destination: AppScreen(tab: screen, embedInNavigation: false)) {
                    SettingsRow(title: LocalizedStringKey(screen.title), icon: screen.icon, color: screen.color)
                }
            }

            NavigationLink(destination: TabBarSettingsView()) {
                SettingsRow(title: "Tab Bar", icon: "dock.rectangle", color: .gray)
            }
            NavigationLink(destination: DashboardLayoutView()) {
                SettingsRow(title: "Overview Layout", icon: "rectangle.3.group.fill", color: .blue)
            }
        } header: {
            Text("Finance")
        }
    }

    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                SettingsRow(title: "Theme", icon: "circle.lefthalf.filled", color: .indigo)
                Picker("Theme", selection: $themeRaw) {
                    ForEach([AppTheme.system, .light, .dark], id: \.self) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)

            NavigationLink(destination: AppIconPickerView()) {
                SettingsRow(title: "App Icon", icon: "app.badge.fill", color: .pink)
            }

            Toggle(isOn: $showCategoryIcons) {
                SettingsRow(title: "Category Icons", icon: "square.grid.2x2.fill", color: .orange)
            }

            Picker(selection: $pickerStyleRaw) {
                ForEach(CategoryPickerStyle.allCases) { style in
                    Text(style.title).tag(style.rawValue)
                }
            } label: {
                SettingsRow(title: "Category Picker", icon: "hand.tap.fill", color: .blue)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("System theme switches between light and dark automatically with your iPhone. Compact grid shows 3 categories and a ⋯ button that expands the full list right in the form.")
        }
    }

    private var transactionsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { saveLocation },
                set: { newValue in
                    saveLocation = newValue
                    guard newValue else { return }
                    Task {
                        let allowed = await LocationService.shared.requestAuthorization()
                        if !allowed {
                            saveLocation = false
                            showLocationDenied = true
                        }
                    }
                }
            )) {
                SettingsRow(title: "Save Location", icon: "location.fill", color: .blue)
            }
        } header: {
            Text("Transactions")
        } footer: {
            Text("New transactions remember where they were added. You can remove the location from any transaction.")
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker(selection: $currencyCode) {
                ForEach(AppCurrency.all) { currency in
                    Text(verbatim: "\(currency.code) (\(currency.symbol)) — \(currency.name.localized)").tag(currency.code)
                }
            } label: {
                SettingsRow(title: "Currency", icon: "banknote.fill", color: .green)
            }

            Button(action: openAppSettings) {
                HStack {
                    SettingsRow(title: "Language", icon: "globe", color: .blue)
                    Spacer()
                    Text(currentLanguageName)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

            Toggle(isOn: Binding(
                get: { viewModel.settings.notificationEnabled },
                set: { viewModel.setNotifications($0) }
            )) {
                SettingsRow(title: "Reminders", icon: "bell.badge.fill", color: .red)
            }
        }
    }

    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    /// iOS shows the per-app language choice on the app's page in Settings.
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
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
                    SettingsRow(title: LocalizedStringKey(viewModel.biometricType), icon: viewModel.biometricIcon, color: .green)
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
                    Text("moneai stores all data locally on your device. No data is collected, transmitted, or shared. Your financial information never leaves your device.")
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
    let title: LocalizedStringKey
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

/// Choose and order up to four tabs; "More" is always the last one.
struct TabBarSettingsView: View {
    @EnvironmentObject var router: TabRouter

    var body: some View {
        List {
            Section {
                ForEach(router.tabs) { tab in
                    tabRow(tab)
                }
                .onMove { source, destination in
                    var tabs = router.tabs
                    tabs.move(fromOffsets: source, toOffset: destination)
                    router.setTabs(tabs)
                }
                .onDelete { offsets in
                    var tabs = router.tabs
                    tabs.remove(atOffsets: offsets)
                    router.setTabs(tabs)
                }
                .deleteDisabled(router.tabs.count <= 1)

                tabRow(.more)
                    .foregroundColor(.secondary)
            } header: {
                Text("In Tab Bar")
            } footer: {
                Text("Up to %lld tabs plus More. Drag to reorder. Removed screens stay available in More.".localizedFormat(TabRouter.maxTabs))
            }

            Section("Available") {
                if router.hiddenScreens.isEmpty {
                    Text("All screens are in the tab bar")
                        .foregroundColor(.secondary)
                }
                ForEach(router.hiddenScreens) { screen in
                    Button {
                        withAnimation { router.setTabs(router.tabs + [screen]) }
                    } label: {
                        HStack {
                            tabRow(screen)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(router.tabs.count < TabRouter.maxTabs ? .green : Color(.tertiaryLabel))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(router.tabs.count >= TabRouter.maxTabs)
                }
            }
        }
        .listStyle(.insetGrouped)
        // Always in edit mode: reorder handles and delete buttons are the whole point here.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Tab Bar")
    }

    private func tabRow(_ tab: AppTab) -> some View {
        SettingsRow(title: LocalizedStringKey(tab.title), icon: tab.icon, color: tab.color)
    }
}

/// Which cards the Overview shows, in which order, and how categories are drawn.
struct DashboardLayoutView: View {
    @AppStorage(AppPreferences.dashboardSectionsKey)
    private var sectionsRaw = DashboardSection.encode(DashboardSection.defaultOrder)
    @AppStorage(AppPreferences.dashboardCategoryStyleKey)
    private var categoryStyleRaw = CategoryChartStyle.donut.rawValue

    private var shown: [DashboardSection] {
        DashboardSection.decode(sectionsRaw)
    }

    private var hidden: [DashboardSection] {
        DashboardSection.allCases.filter { !shown.contains($0) }
    }

    var body: some View {
        List {
            Section {
                Picker("Expenses by Category", selection: $categoryStyleRaw) {
                    ForEach(CategoryChartStyle.allCases) { style in
                        Label(style.title, systemImage: style.icon).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            } header: {
                Text("Expenses by Category")
            } footer: {
                Text("Donut fills by each category's share of this month's expenses.")
            }

            Section {
                ForEach(shown) { section in
                    sectionRow(section)
                }
                .onMove { source, destination in
                    var list = shown
                    list.move(fromOffsets: source, toOffset: destination)
                    sectionsRaw = DashboardSection.encode(list)
                }
                .onDelete { offsets in
                    var list = shown
                    list.remove(atOffsets: offsets)
                    sectionsRaw = DashboardSection.encode(list)
                }
            } header: {
                Text("Shown")
            } footer: {
                Text("The balance card is always at the top. Drag to reorder.")
            }

            if !hidden.isEmpty {
                Section("Hidden") {
                    ForEach(hidden) { section in
                        Button {
                            withAnimation { sectionsRaw = DashboardSection.encode(shown + [section]) }
                        } label: {
                            HStack {
                                sectionRow(section)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Overview Layout")
    }

    private func sectionRow(_ section: DashboardSection) -> some View {
        SettingsRow(title: LocalizedStringKey(section.title), icon: section.icon, color: .blue)
    }
}

struct AppIconPickerView: View {
    @AppStorage(AppIconManager.styleKey) private var styleRaw = AppIconStyle.classic.rawValue
    @AppStorage(AppIconManager.matchCurrencyKey) private var matchesCurrency = false
    @AppStorage(AppCurrency.storageKey) private var currencyCode: String = AppCurrency.defaultCode
    @State private var errorMessage: String?

    private var glyph: AppIconGlyph {
        matchesCurrency ? .forCurrency(currencyCode) : .neutral
    }

    var body: some View {
        List {
            Section {
                Toggle("Currency Sign on Icon", isOn: Binding(
                    get: { matchesCurrency },
                    set: { newValue in
                        matchesCurrency = newValue
                        apply()
                    }
                ))
            } footer: {
                if matchesCurrency && glyph == .neutral {
                    Text("There is no icon for this currency yet, so the wallet is used.")
                } else {
                    Text("The icon shows ₸, ₽, $ or € and changes when you switch currency. Otherwise a wallet is shown.")
                }
            }

            Section("Style") {
                ForEach(AppIconStyle.allCases) { style in
                    Button {
                        styleRaw = style.rawValue
                        apply()
                    } label: {
                        HStack(spacing: 16) {
                            Image(AppIconManager.previewImage(style: style, glyph: glyph))
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13.5, style: .continuous)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )

                            Text(style.title)
                                .foregroundColor(.primary)

                            Spacer()

                            if styleRaw == style.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
    }

    private func apply() {
        AppIconManager.applyCurrent { error in
            errorMessage = error?.localizedDescription
            if error == nil {
                Haptics.success()
            }
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
        .environmentObject(TabRouter())
}
