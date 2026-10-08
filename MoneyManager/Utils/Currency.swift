import Foundation

struct CurrencyInfo: Identifiable, Hashable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }
}

/// Single source of truth for the app currency. The selected code lives in
/// UserDefaults under `storageKey` so views can observe it with `@AppStorage`.
enum AppCurrency {
    static let storageKey = "currencyCode"
    static let defaultCode = "KZT"

    static let all: [CurrencyInfo] = [
        CurrencyInfo(code: "KZT", symbol: "₸", name: "Kazakhstani Tenge"),
        CurrencyInfo(code: "RUB", symbol: "₽", name: "Russian Ruble"),
        CurrencyInfo(code: "USD", symbol: "$", name: "US Dollar"),
        CurrencyInfo(code: "EUR", symbol: "€", name: "Euro"),
        CurrencyInfo(code: "GBP", symbol: "£", name: "British Pound"),
        CurrencyInfo(code: "UZS", symbol: "soʻm", name: "Uzbekistani Som"),
        CurrencyInfo(code: "KGS", symbol: "сом", name: "Kyrgyzstani Som"),
        CurrencyInfo(code: "CNY", symbol: "¥", name: "Chinese Yuan"),
        CurrencyInfo(code: "TRY", symbol: "₺", name: "Turkish Lira"),
        CurrencyInfo(code: "AED", symbol: "AED", name: "UAE Dirham")
    ]

    static var code: String {
        UserDefaults.standard.string(forKey: storageKey) ?? defaultCode
    }

    static var symbol: String {
        info(for: code).symbol
    }

    static func info(for code: String) -> CurrencyInfo {
        all.first { $0.code == code } ?? CurrencyInfo(code: code, symbol: code, name: code)
    }

    static func format(_ amount: Double, code: String? = nil) -> String {
        let currency = info(for: code ?? self.code)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency.symbol)"
    }

    /// Parses user input. Accepts both "12.5" and "12,5" (the decimal pad shows a
    /// comma on ru/kk locales) and ignores grouping spaces.
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// Text for pre-filling an amount field when editing.
    static func editString(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }
}
