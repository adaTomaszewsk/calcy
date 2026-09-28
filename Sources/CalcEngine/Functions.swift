import Foundation

enum Function {
    case sqrt, cbrt, abs, round, floor, ceil, min, max
    case sin, cos, tan, asin, acos, atan
    case ln, log, log2, exp, pow, factorial

    static func named(_ name: String) -> Function? {
        names[name.lowercased()]
    }

    private static let names: [String: Function] = [
        "sqrt": .sqrt, "pierwiastek": .sqrt, "pierw": .sqrt,
        "cbrt": .cbrt,
        "abs": .abs,
        "round": .round, "zaokrąglij": .round, "zaokraglij": .round, "zaokr": .round,
        "floor": .floor, "podłoga": .floor, "podloga": .floor,
        "ceil": .ceil, "sufit": .ceil,
        "min": .min, "max": .max,
        "sin": .sin, "cos": .cos, "tan": .tan, "tg": .tan,
        "asin": .asin, "arcsin": .asin, "acos": .acos, "arccos": .acos, "atan": .atan, "arctg": .atan,
        "ln": .ln, "log": .log, "log2": .log2,
        "exp": .exp,
        "pow": .pow, "potęga": .pow, "potega": .pow,
        "fact": .factorial, "silnia": .factorial,
    ]

    func apply(_ name: String, _ args: [Decimal]) throws -> Decimal {
        func arity(_ allowed: ClosedRange<Int>) throws {
            guard allowed.contains(args.count) else { throw CalcError.wrongArgumentCount(name) }
        }
        func viaDouble(_ f: (Double) -> Double) throws -> Decimal {
            try arity(1...1)
            return try DecimalMath.fromDouble(f(DecimalMath.toDouble(args[0])), name)
        }

        switch self {
        case .sqrt:
            try arity(1...1)
            guard args[0] >= 0 else { throw CalcError.undefined("pierwiastek z liczby ujemnej") }
            return try viaDouble(Foundation.sqrt)
        case .cbrt: return try viaDouble(Foundation.cbrt)
        case .abs:
            try arity(1...1)
            return args[0].magnitude
        case .round:
            try arity(1...2)
            let digits = args.count == 2 ? try DecimalMath.toInt(args[1]) : 0
            return DecimalMath.rounded(args[0], scale: digits)
        case .floor:
            try arity(1...1)
            return DecimalMath.floor(args[0])
        case .ceil:
            try arity(1...1)
            return DecimalMath.ceil(args[0])
        case .min:
            guard let m = args.min() else { throw CalcError.wrongArgumentCount(name) }
            return m
        case .max:
            guard let m = args.max() else { throw CalcError.wrongArgumentCount(name) }
            return m
        case .sin: return try viaDouble(Foundation.sin)
        case .cos: return try viaDouble(Foundation.cos)
        case .tan: return try viaDouble(Foundation.tan)
        case .asin: return try viaDouble(Foundation.asin)
        case .acos: return try viaDouble(Foundation.acos)
        case .atan: return try viaDouble(Foundation.atan)
        case .ln:
            try arity(1...1)
            guard args[0] > 0 else { throw CalcError.undefined("logarytm z liczby niedodatniej") }
            return try viaDouble(Foundation.log)
        case .log:
            try arity(1...2)
            guard args[0] > 0 else { throw CalcError.undefined("logarytm z liczby niedodatniej") }
            let x = DecimalMath.toDouble(args[0])
            let base = args.count == 2 ? DecimalMath.toDouble(args[1]) : 10
            return try DecimalMath.fromDouble(Foundation.log(x) / Foundation.log(base), name)
        case .log2:
            try arity(1...1)
            guard args[0] > 0 else { throw CalcError.undefined("logarytm z liczby niedodatniej") }
            return try viaDouble(Foundation.log2)
        case .exp: return try viaDouble(Foundation.exp)
        case .pow:
            try arity(2...2)
            return try DecimalMath.power(args[0], args[1])
        case .factorial:
            try arity(1...1)
            let n = try DecimalMath.toInt(args[0])
            guard (0...170).contains(n) else { throw CalcError.overflow }
            return try (1...Swift.max(n, 1)).reduce(Decimal(1)) { try DecimalMath.checked($0 * Decimal($1)) }
        }
    }
}
