import SwiftUI

/// UserDefaults keys for display preferences, read with `@AppStorage`.
enum AppPreferences {
    static let showCategoryIconsKey = "showCategoryIcons"
    static let categoryPickerStyleKey = "categoryPickerStyle"
    static let saveLocationKey = "saveTransactionLocation"
    static let dashboardSectionsKey = "dashboardSections"
    static let dashboardCategoryStyleKey = "dashboardCategoryStyle"
}

// MARK: - Tab bar

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, transactions, debts, reports, accounts, categories, budgets, goals, bills
    /// Always the last tab; holds settings and every screen that isn't in the tab bar.
    case more

    var id: String { rawValue }

    /// Screens the user can put in the tab bar.
    static let customizable: [AppTab] = [
        .dashboard, .transactions, .debts, .reports, .accounts, .categories, .budgets, .goals, .bills
    ]

    /// Localization key of the title.
    var title: String {
        switch self {
        case .dashboard: return "Overview"
        case .transactions: return "Transactions"
        case .debts: return "Debts"
        case .reports: return "Reports"
        case .accounts: return "Accounts"
        case .categories: return "Categories"
        case .budgets: return "Budgets"
        case .goals: return "Savings Goals"
        case .bills: return "Bills & Subscriptions"
        case .more: return "More"
        }
    }

    /// Short title for the tab bar, where long names don't fit.
    var tabTitle: String {
        switch self {
        case .goals: return "Goals"
        case .bills: return "Bills"
        default: return title
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .transactions: return "list.bullet.rectangle"
        case .debts: return "person.2.fill"
        case .reports: return "chart.pie.fill"
        case .accounts: return "creditcard.fill"
        case .categories: return "square.grid.2x2.fill"
        case .budgets: return "chart.bar.fill"
        case .goals: return "target"
        case .bills: return "doc.text.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return .blue
        case .transactions: return .indigo
        case .debts: return .orange
        case .reports: return .pink
        case .accounts: return .blue
        case .categories: return .orange
        case .budgets: return .green
        case .goals: return .purple
        case .bills: return .red
        case .more: return .gray
        }
    }
}

/// Which screens are in the tab bar (user-configurable) and which tab is selected.
final class TabRouter: ObservableObject {
    static let storageKey = "tabBarItems"
    /// iOS fits five tabs; the fifth is always "More".
    static let maxTabs = 4
    static let defaultTabs: [AppTab] = [.dashboard, .transactions, .debts, .reports]

    @Published var selection: AppTab
    @Published private(set) var tabs: [AppTab]

    init() {
        let saved = TabRouter.loadTabs()
        tabs = saved
        selection = saved.first ?? .more
    }

    private static func loadTabs() -> [AppTab] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return defaultTabs }
        let saved = raw.split(separator: ",").compactMap { AppTab(rawValue: String($0)) }
        return sanitized(saved)
    }

    private static func sanitized(_ list: [AppTab]) -> [AppTab] {
        var unique: [AppTab] = []
        for tab in list where tab != .more && !unique.contains(tab) {
            unique.append(tab)
        }
        return Array(unique.prefix(maxTabs))
    }

    func setTabs(_ newTabs: [AppTab]) {
        tabs = TabRouter.sanitized(newTabs)
        UserDefaults.standard.set(tabs.map { $0.rawValue }.joined(separator: ","), forKey: TabRouter.storageKey)
        if selection != .more && !tabs.contains(selection) {
            selection = tabs.first ?? .more
        }
    }

    /// Screens reachable only through "More".
    var hiddenScreens: [AppTab] {
        AppTab.customizable.filter { !tabs.contains($0) }
    }

    /// Switches to the tab if it's in the tab bar; returns `false` when it isn't.
    @discardableResult
    func show(_ tab: AppTab) -> Bool {
        guard tabs.contains(tab) else { return false }
        selection = tab
        return true
    }
}

// MARK: - Overview layout

enum DashboardSection: String, CaseIterable, Identifiable {
    case accounts, debts, recent, categories

    var id: String { rawValue }

    static let defaultOrder: [DashboardSection] = [.accounts, .debts, .recent, .categories]

    var title: String {
        switch self {
        case .accounts: return "Accounts"
        case .debts: return "Debts"
        case .recent: return "Recent Transactions"
        case .categories: return "Expenses by Category"
        }
    }

    var icon: String {
        switch self {
        case .accounts: return "creditcard.fill"
        case .debts: return "person.2.fill"
        case .recent: return "list.bullet.rectangle"
        case .categories: return "chart.pie.fill"
        }
    }

    /// Visible sections in order, stored as "accounts,debts,...". Hidden ones are left out.
    static func decode(_ raw: String) -> [DashboardSection] {
        var unique: [DashboardSection] = []
        for part in raw.split(separator: ",") {
            if let section = DashboardSection(rawValue: String(part)), !unique.contains(section) {
                unique.append(section)
            }
        }
        return unique
    }

    static func encode(_ sections: [DashboardSection]) -> String {
        sections.map { $0.rawValue }.joined(separator: ",")
    }
}

enum CategoryChartStyle: String, CaseIterable, Identifiable {
    case donut, list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .donut: return "Donut".localized
        case .list: return "List".localized
        }
    }

    var icon: String {
        switch self {
        case .donut: return "chart.pie"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Localization

extension String {
    /// Looks the string up in Localizable.strings; returns it unchanged if there's no translation.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localizedFormat(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Category picker

enum CategoryPickerStyle: String, CaseIterable, Identifiable {
    /// Horizontal scrolling row of all categories.
    case carousel
    /// Three categories plus "⋯" that expands the full grid in place.
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .carousel: return "Carousel".localized
        case .grid: return "Compact grid".localized
        }
    }
}

// MARK: - Theme

enum ThemeManager {
    /// Sets the style on the windows directly: `.preferredColorScheme(nil)` doesn't reliably
    /// switch back to the system appearance after Light/Dark was chosen.
    static func apply(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle
        switch theme {
        case .light: style = .light
        case .dark: style = .dark
        case .system: style = .unspecified
        }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

// MARK: - App icon

/// Color style of the app icon. Each style exists with every glyph in Assets.xcassets
/// (generated by tools/generate_icons.py).
enum AppIconStyle: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case midnight = "Midnight"
    case emerald = "Emerald"
    case sunset = "Sunset"
    case minimal = "Minimal"

    var id: String { rawValue }

    var title: String { rawValue.localized }
}

/// Symbol on the app icon: a neutral wallet, or the sign of the selected currency.
enum AppIconGlyph: String {
    case neutral = "Neutral"
    case tenge = "Tenge"
    case ruble = "Ruble"
    case dollar = "Dollar"
    case euro = "Euro"

    /// Currencies without their own icon use the wallet.
    static func forCurrency(_ code: String) -> AppIconGlyph {
        switch code {
        case "KZT": return .tenge
        case "RUB": return .ruble
        case "USD": return .dollar
        case "EUR": return .euro
        default: return .neutral
        }
    }
}

enum AppIconManager {
    static let styleKey = "appIconStyle"
    static let matchCurrencyKey = "appIconMatchesCurrency"

    static var style: AppIconStyle {
        AppIconStyle(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "") ?? .classic
    }

    static var matchesCurrency: Bool {
        UserDefaults.standard.bool(forKey: matchCurrencyKey)
    }

    static func glyph(matchesCurrency: Bool = AppIconManager.matchesCurrency) -> AppIconGlyph {
        matchesCurrency ? .forCurrency(AppCurrency.code) : .neutral
    }

    /// `nil` is the primary "AppIcon" (Classic + wallet).
    static func iconName(style: AppIconStyle, glyph: AppIconGlyph) -> String? {
        if style == .classic && glyph == .neutral { return nil }
        return "AppIcon-\(style.rawValue)-\(glyph.rawValue)"
    }

    static func previewImage(style: AppIconStyle, glyph: AppIconGlyph) -> String {
        "IconPreview-\(style.rawValue)-\(glyph.rawValue)"
    }

    /// Sets the icon from the saved style, the "match currency" switch and the current currency.
    /// iOS shows its own "You have changed the icon" alert whenever the icon actually changes.
    static func applyCurrent(completion: ((Error?) -> Void)? = nil) {
        let name = iconName(style: style, glyph: glyph())
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != name else {
            completion?(nil)
            return
        }
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
}
