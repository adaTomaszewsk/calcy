import Foundation

enum DecimalMath {
    static func rounded(_ x: Decimal, scale: Int = 0, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var input = x
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, mode)
        return result
    }

    static func floor(_ x: Decimal) -> Decimal {
        let r = rounded(x)
        return r > x ? r - 1 : r
    }

    static func ceil(_ x: Decimal) -> Decimal {
        let r = rounded(x)
        return r < x ? r + 1 : r
    }

    static func isInteger(_ x: Decimal) -> Bool {
        rounded(x) == x
    }

    /// Wartość bezwzględna liczby całkowitej mieszczącej się w UInt64 (do wyświetlania hex/bin/oct).
    static func integerMagnitude(_ x: Decimal) -> (negative: Bool, magnitude: UInt64)? {
        guard x.isFinite, isInteger(x) else { return nil }
        let magnitude = x < 0 ? -x : x
        guard magnitude <= Decimal(UInt64.max), let value = UInt64(magnitude.description) else { return nil }
        return (x < 0, value)
    }

    static func toInt64(_ x: Decimal) throws -> Int64 {
        guard x.isFinite, isInteger(x), x >= Decimal(Int64.min), x <= Decimal(Int64.max),
              let value = Int64(x.description)
        else { throw CalcError.notAnInteger }
        return value
    }

    static func toInt(_ x: Decimal) throws -> Int {
        Int(try toInt64(x))
    }

    static func toDouble(_ x: Decimal) -> Double {
        NSDecimalNumber(decimal: x).doubleValue
    }

    static func fromDouble(_ d: Double, _ what: String) throws -> Decimal {
        if d.isNaN { throw CalcError.undefined(what) }
        if d.isInfinite { throw CalcError.overflow }
        // Zaokrąglenie do 15 cyfr znaczących usuwa szum binarny (np. sin(pi) → 0).
        return Decimal(string: String(format: "%.15g", d), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(d)
    }

    static func checked(_ x: Decimal) throws -> Decimal {
        guard !x.isNaN else { throw CalcError.overflow }
        return x
    }

    static func divide(_ a: Decimal, _ b: Decimal) throws -> Decimal {
        guard !b.isZero else { throw CalcError.divisionByZero }
        return try checked(a / b)
    }

    /// Reszta z dzielenia ze znakiem dzielnika (jak w Pythonie): `-7 mod 3 = 2`.
    static func modulo(_ a: Decimal, _ b: Decimal) throws -> Decimal {
        guard !b.isZero else { throw CalcError.divisionByZero }
        return try checked(a - b * floor(a / b))
    }

    static func power(_ base: Decimal, _ exponent: Decimal) throws -> Decimal {
        if isInteger(exponent), exponent.magnitude <= 10_000, let n = Int(exponent.description) {
            if n >= 0 {
                return try checked(Foundation.pow(base, n))
            }
            return try divide(1, try checked(Foundation.pow(base, -n)))
        }
        return try fromDouble(Foundation.pow(toDouble(base), toDouble(exponent)), "potęga")
    }
}
