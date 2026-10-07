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
            (a, r, g, b) = (1, 1, 1, 0)
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
}

extension Double {
    func formattedAsCurrency(code: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
}
