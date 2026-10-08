import SwiftUI

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

    /// Text for pre-filling an amount field when editing, e.g. "15 000,5".
    static func editString(_ amount: Double) -> String {
        let raw = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", amount)
            : String(format: "%.2f", amount)
        return formatInput(raw, allowsNegative: true)
    }

    private static let groupingSeparator = "\u{00A0}"

    private static var decimalSeparator: Character {
        Character(Locale.current.decimalSeparator ?? ".")
    }

    /// Re-formats text typed into an amount field: groups thousands ("1500000" → "1 500 000"),
    /// keeps a single decimal separator and at most 2 fraction digits.
    static func formatInput(_ text: String, allowsNegative: Bool = false) -> String {
        var isNegative = false
        var integerDigits = ""
        var fraction: String?

        for char in text {
            if ("0"..."9").contains(char) {
                if fraction == nil {
                    integerDigits.append(char)
                } else if fraction!.count < 2 {
                    fraction!.append(char)
                }
            } else if (char == "," || char == ".") && fraction == nil {
                fraction = ""
            } else if char == "-" && allowsNegative && integerDigits.isEmpty && fraction == nil {
                isNegative = true
            }
        }

        while integerDigits.count > 1 && integerDigits.first == "0" {
            integerDigits.removeFirst()
        }
        if integerDigits.isEmpty && fraction != nil {
            integerDigits = "0"
        }

        var groups: [String] = []
        var remaining = Substring(integerDigits)
        while remaining.count > 3 {
            groups.insert(String(remaining.suffix(3)), at: 0)
            remaining = remaining.dropLast(3)
        }
        if !remaining.isEmpty {
            groups.insert(String(remaining), at: 0)
        }

        var result = (isNegative ? "-" : "") + groups.joined(separator: groupingSeparator)
        if let fraction = fraction {
            result += String(decimalSeparator) + fraction
        }
        return result
    }
}

extension Binding where Value == String {
    /// Binding for amount text fields that groups thousands while the user types.
    func amountFormatted(allowsNegative: Bool = false) -> Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = AppCurrency.formatInput($0, allowsNegative: allowsNegative) }
        )
    }
}
