import SwiftUI

/// UserDefaults keys for display preferences, read with `@AppStorage`.
enum AppPreferences {
    static let showCategoryIconsKey = "showCategoryIcons"
    static let categoryPickerStyleKey = "categoryPickerStyle"
    static let saveLocationKey = "saveTransactionLocation"
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

struct AppIconOption: Identifiable, Hashable {
    /// Name of the alternate icon set; `nil` is the primary `AppIcon`.
    let iconName: String?
    let title: String
    /// Image set with a preview, since app icon sets can't be loaded with `Image(_:)`.
    let previewImage: String

    var id: String { iconName ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(iconName: nil, title: "Classic", previewImage: "IconPreview-Default"),
        AppIconOption(iconName: "AppIcon-Dark", title: "Midnight", previewImage: "IconPreview-Dark"),
        AppIconOption(iconName: "AppIcon-Green", title: "Emerald", previewImage: "IconPreview-Green"),
        AppIconOption(iconName: "AppIcon-Sunset", title: "Sunset", previewImage: "IconPreview-Sunset"),
        AppIconOption(iconName: "AppIcon-Mono", title: "Minimal", previewImage: "IconPreview-Mono")
    ]
}
