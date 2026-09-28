import Foundation

/// System liczbowy, w którym wynik ma zostać wyświetlony.
public enum Radix: Sendable, Equatable {
    case decimal
    case hexadecimal
    case binary
    case octal

    var base: Int {
        switch self {
        case .decimal: 10
        case .hexadecimal: 16
        case .binary: 2
        case .octal: 8
        }
    }
}

/// Wynik obliczenia.
public enum Value: Sendable, Equatable {
    case number(Decimal, Radix)
    case money(Decimal, Currency)
    /// Okres czasu, np. `7 dni`.
    case duration(Decimal, TimeUnit)
    /// Data; `hasTime` mówi, czy pokazywać godzinę.
    case date(Date, hasTime: Bool)
    /// Miara lub waga, np. `5 km`, `2,5 kg`.
    case measure(Decimal, PhysicalUnit)

    public init(_ number: Decimal, radix: Radix = .decimal) {
        self = .number(number, radix)
    }
}

/// Jednostka doklejana do liczby (`5 USD`, `3 dni`) albo cel konwersji (`in EUR`, `w dniach`, `in hex`).
enum Quantity: Equatable {
    case currency(Currency)
    case unit(TimeUnit)
    case physical(PhysicalUnit)

    static func named(_ word: String) -> Quantity? {
        if let currency = Currency.named(word) { return .currency(currency) }
        if let unit = TimeUnit.named(word) { return .unit(unit) }
        if let unit = PhysicalUnit.named(word) { return .physical(unit) }
        return nil
    }
}

enum Conversion: Equatable {
    case radix(Radix)
    case quantity(Quantity)

    static func named(_ word: String) -> Conversion? {
        if let radix = Keywords.radix[word.lowercased()] { return .radix(radix) }
        return Quantity.named(word).map(Conversion.quantity)
    }
}
