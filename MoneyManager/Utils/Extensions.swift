import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }

    func endOfMonth() -> Date {
        let calendar = Calendar.current
        let components = DateComponents(month: 1, day: -1)
        return calendar.date(byAdding: components, to: self.startOfMonth())!
    }

    func isToday() -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
    }

    func isThisWeek() -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    func isThisMonth() -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Full calendar period containing this date, e.g. the whole month.
    /// `end` is exclusive (start of the next period), so pair it with `date < end`.
    func interval(of component: Calendar.Component) -> DateInterval {
        Calendar.current.dateInterval(of: component, for: self) ?? DateInterval(start: self, duration: 0)
    }
}

extension Double {
    func formattedAsCurrency(code: String? = nil) -> String {
        AppCurrency.format(self, code: code)
    }

    /// "+1 500 ₸" / "−1 500 ₸"
    var signedCurrency: String {
        (self >= 0 ? "+" : "") + formattedAsCurrency()
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Styling

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

// MARK: - Keyboard

/// Hides the keyboard when the user taps anywhere outside a text field, app-wide.
/// `cancelsTouchesInView = false` keeps buttons and rows working as usual.
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private let recognizerName = "dismissKeyboardOnTap"

    /// Lists, forms and scroll views hide the keyboard as soon as they're dragged
    /// (`.scrollDismissesKeyboard` needs iOS 16; this works on iOS 15 too).
    static func configureScrollViews() {
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }

    /// Call once windows exist (e.g. from the root view's onAppear). Safe to call repeatedly.
    func install() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows
            where !(window.gestureRecognizers ?? []).contains(where: { $0.name == recognizerName }) {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tap.name = recognizerName
                tap.cancelsTouchesInView = false
                tap.delegate = self
                window.addGestureRecognizer(tap)
            }
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Tapping into another field should move focus there, not close the keyboard.
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
