import Foundation

/// Zamienia wartości na tekst. Domyślnie używa ustawień systemu (w Polsce: `1 234,5`).
public struct ValueFormatter: Sendable {
    public var decimalSeparator: String
    public var groupingSeparator: String
    public var maximumFractionDigits = 10
    public var locale: Locale
    public var calendar: Calendar

    public init(decimalSeparator: String, groupingSeparator: String, locale: Locale = .current, calendar: Calendar = .current) {
        self.decimalSeparator = decimalSeparator
        self.groupingSeparator = groupingSeparator
        self.locale = locale
        self.calendar = calendar
    }

    public init(locale: Locale = .current, calendar: Calendar = .current) {
        self.init(
            decimalSeparator: locale.decimalSeparator ?? ".",
            groupingSeparator: locale.groupingSeparator ?? " ",
            locale: locale,
            calendar: calendar
        )
    }

    /// - Parameter grouping: `false` daje tekst gotowy do wklejenia z powrotem do kalkulatora.
    public func format(_ value: Value, grouping: Bool = true) -> String {
        switch value {
        case .number(let number, let radix):
            return formatNumber(number, radix: radix, grouping: grouping)
        case .money(let amount, let currency):
            let text = formatDecimal(amount, maximumFractionDigits: 2, minimumFractionDigits: 2, grouping: grouping)
            return "\(text) \(currency.symbol)"
        case .duration(let amount, let unit):
            let rounded = DecimalMath.rounded(amount, scale: 2)
            return "\(formatDecimal(rounded, maximumFractionDigits: 2, grouping: grouping)) \(unit.polishName(for: rounded))"
        case .measure(let amount, let unit):
            return "\(formatDecimal(amount, maximumFractionDigits: maximumFractionDigits, grouping: grouping)) \(unit.symbol)"
        case .date(let date, let hasTime):
            return grouping ? formatDateLong(date, hasTime: hasTime) : formatDateShort(date, hasTime: hasTime)
        }
    }

    private func formatNumber(_ number: Decimal, radix: Radix, grouping: Bool) -> String {
        guard radix != .decimal, let (negative, magnitude) = DecimalMath.integerMagnitude(number) else {
            return formatDecimal(number, maximumFractionDigits: maximumFractionDigits, grouping: grouping)
        }
        let prefix = switch radix {
        case .hexadecimal: "0x"
        case .binary: "0b"
        case .octal: "0o"
        case .decimal: ""
        }
        return (negative ? "-" : "") + prefix + String(magnitude, radix: radix.base, uppercase: true)
    }

    private func formatDecimal(
        _ number: Decimal,
        maximumFractionDigits: Int,
        minimumFractionDigits: Int = 0,
        grouping: Bool
    ) -> String {
        var rounded = DecimalMath.rounded(number, scale: maximumFractionDigits)
        if rounded.isZero { rounded = 0 }
        let negative = rounded < 0
        let parts = (negative ? -rounded : rounded).description.split(separator: ".", maxSplits: 1)
        var integer = String(parts[0])
        var fraction = parts.count > 1 ? String(parts[1]) : ""
        if fraction.count < minimumFractionDigits {
            fraction += String(repeating: "0", count: minimumFractionDigits - fraction.count)
        }

        // Decimal jest dokładny do 38 cyfr – dłuższe liczby pokazujemy w notacji naukowej.
        if integer.count > 38 {
            return String(format: "%.6e", DecimalMath.toDouble(number))
                .replacingOccurrences(of: ".", with: decimalSeparator)
        }
        // Grupujemy od 5 cyfr – tak jak w polskiej typografii „1280”, ale „12 800”.
        if grouping, integer.count > 4 {
            var groups: [Substring] = []
            var end = integer.endIndex
            while end > integer.startIndex {
                let start = integer.index(end, offsetBy: -3, limitedBy: integer.startIndex) ?? integer.startIndex
                groups.insert(integer[start..<end], at: 0)
                end = start
            }
            integer = groups.joined(separator: groupingSeparator)
        }
        return (negative ? "-" : "") + integer + (fraction.isEmpty ? "" : decimalSeparator + fraction)
    }

    /// `pt., 25 grudnia 2026`, a z godziną – bez dnia tygodnia: `25 grudnia 2026 o 14:30`.
    private func formatDateLong(_ date: Date, hasTime: Bool) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if hasTime {
            return date.formatted(style.day().month(.wide).year().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        return date.formatted(style.weekday(.abbreviated).day().month(.wide).year())
    }

    /// `25.12.2026` – format, który kalkulator potrafi wczytać z powrotem.
    private func formatDateShort(_ date: Date, hasTime: Bool) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let day = String(format: "%02d.%02d.%04d", c.day ?? 0, c.month ?? 0, c.year ?? 0)
        return hasTime ? day + String(format: " %02d:%02d", c.hour ?? 0, c.minute ?? 0) : day
    }
}
