import Foundation

/// Stan widoczny podczas liczenia jednej linii.
struct Context {
    var variables: [String: Value] = [:]
    /// Wynik ostatniej poprawnie policzonej linii (`prev`).
    var previous: Value?
    /// Wyniki bieżącego bloku – od ostatniej pustej linii lub nagłówka (`sum`, `avg`).
    var block: [Value] = []
    var now: Date
    var calendar: Calendar
    var rates: ExchangeRates?
}

enum Evaluator {
    static func evaluate(_ expression: Expression, in context: Context) throws -> Value {
        switch expression {
        case .number(let value, let radix):
            return .number(value, radix)

        case .date(let year, let month, let day):
            return try date(year: year, month: month, day: day, calendar: context.calendar)

        case .variable(let name):
            return try lookup(name, in: context)

        case .quantity(let inner, let quantity):
            // `5 USD` – liczba dostaje jednostkę. Wartość, która już ją ma, nie może dostać drugiej.
            let value = try evaluate(inner, in: context)
            guard case .number = value else { throw CalcError.typeMismatch }
            return try convert(value, to: .quantity(quantity), in: context)

        case .unary(let op, let operand):
            let value = try evaluate(operand, in: context)
            switch (op, value) {
            case (.negate, .number(let n, let radix)): return .number(-n, radix)
            case (.negate, .money(let n, let currency)): return .money(-n, currency)
            case (.negate, .duration(let n, let unit)): return .duration(-n, unit)
            case (.negate, .measure(let n, let unit)): return .measure(-n, unit)
            case (.bitNot, .number(let n, let radix)): return .number(Decimal(~(try DecimalMath.toInt64(n))), radix)
            default: throw CalcError.typeMismatch
            }

        case .binary(let op, let lhs, let rhs):
            return try binary(op, try evaluate(lhs, in: context), try evaluate(rhs, in: context), in: context)

        case .call(let name, let arguments):
            guard let function = Function.named(name) else { throw CalcError.unknownFunction(name) }
            let values = try arguments.map { try evaluate($0, in: context) }
            guard let first = values.first else {
                return .number(try function.apply(name, []), .decimal)
            }
            // Funkcje liczą na liczbach; wynik dostaje jednostkę pierwszego argumentu (`round(10,567 USD; 1)`).
            let numbers = try values.map { try numericPart($0, matching: first, in: context) }
            let result = try function.apply(name, numbers)
            switch first {
            case .number(_, let radix): return .number(result, radix)
            case .money(_, let currency): return .money(result, currency)
            case .duration(_, let unit): return .duration(result, unit)
            case .measure(_, let unit): return .measure(result, unit)
            case .date: throw CalcError.typeMismatch
            }
        }
    }

    // MARK: - Konwersje

    static func convert(_ value: Value, to conversion: Conversion, in context: Context) throws -> Value {
        switch (conversion, value) {
        case (.radix(let radix), .number(let n, _)):
            return .number(n, radix)
        case (.quantity(.currency(let currency)), .number(let n, _)):
            return .money(n, currency)
        case (.quantity(.currency(let target)), .money(let n, let source)):
            return .money(try exchange(n, from: source, to: target, in: context), target)
        case (.quantity(.unit(let unit)), .number(let n, _)):
            return .duration(n, unit)
        case (.quantity(.unit(let target)), .duration(let n, let source)):
            return .duration(try source.convert(n, to: target), target)
        case (.quantity(.physical(let unit)), .number(let n, _)):
            return .measure(n, unit)
        case (.quantity(.physical(let target)), .measure(let n, let source)):
            return .measure(try source.convert(n, to: target), target)
        default:
            throw CalcError.typeMismatch
        }
    }

    private static func exchange(_ amount: Decimal, from source: Currency, to target: Currency, in context: Context) throws -> Decimal {
        if source == target { return amount }
        guard let rates = context.rates else { throw CalcError.noExchangeRates }
        return try rates.convert(amount, from: source, to: target)
    }

    private static func numericPart(_ value: Value, matching first: Value, in context: Context) throws -> Decimal {
        switch (value, first) {
        case (.number(let n, _), _): return n
        case (.money(let n, let currency), .money(_, let target)): return try exchange(n, from: currency, to: target, in: context)
        case (.duration(let n, let unit), .duration(_, let target)): return try unit.convert(n, to: target)
        case (.measure(let n, let unit), .measure(_, let target)): return try unit.convert(n, to: target)
        default: throw CalcError.typeMismatch
        }
    }

    // MARK: - Zmienne i słowa kluczowe

    private static func lookup(_ name: String, in context: Context) throws -> Value {
        if let value = context.variables[name] { return value }

        let key = name.lowercased()
        let calendar = context.calendar
        let today = calendar.startOfDay(for: context.now)

        if let constant = Keywords.constants[key] { return Value(constant) }
        if Keywords.today.contains(key) { return .date(today, hasTime: false) }
        if Keywords.now.contains(key) { return .date(context.now, hasTime: true) }
        if Keywords.tomorrow.contains(key) { return try add(1, .day, to: today, hasTime: false, calendar: calendar) }
        if Keywords.yesterday.contains(key) { return try add(-1, .day, to: today, hasTime: false, calendar: calendar) }
        if Keywords.previous.contains(key) {
            guard let previous = context.previous else { throw CalcError.noPreviousResult }
            return previous
        }
        if Keywords.sum.contains(key) {
            return try sum(context.block, in: context)
        }
        if Keywords.average.contains(key) {
            guard !context.block.isEmpty else { throw CalcError.emptyBlock }
            return try binary(.divide, sum(context.block, in: context), Value(Decimal(context.block.count)), in: context)
        }
        throw CalcError.unknownVariable(name)
    }

    private static func sum(_ values: [Value], in context: Context) throws -> Value {
        guard let first = values.first else { return Value(0) }
        return try values.dropFirst().reduce(first) { try binary(.add, $0, $1, in: context) }
    }

    // MARK: - Działania

    private static func binary(_ op: BinaryOperator, _ a: Value, _ b: Value, in context: Context) throws -> Value {
        switch (a, b) {
        case (.number(let x, let rx), .number(let y, let ry)):
            // Wynik zachowuje system liczbowy, jeśli oba argumenty go dzielą (np. 0xF0 | 0x0F → 0xFF).
            return .number(try apply(op, x, y), rx == ry ? rx : .decimal)

        // Waluty: druga kwota jest przeliczana na walutę pierwszej.
        case (.money(let x, let currency), .money(let y, let other)):
            let y = try exchange(y, from: other, to: currency, in: context)
            switch op {
            case .add, .subtract, .modulo: return .money(try apply(op, x, y), currency)
            case .divide: return Value(try apply(op, x, y))
            default: throw CalcError.typeMismatch
            }
        case (.money(let x, let currency), .number(let y, _)):
            guard [.add, .subtract, .multiply, .divide, .modulo].contains(op) else { throw CalcError.typeMismatch }
            return .money(try apply(op, x, y), currency)
        case (.number(let x, _), .money(let y, let currency)):
            guard [.add, .subtract, .multiply].contains(op) else { throw CalcError.typeMismatch }
            return .money(try apply(op, x, y), currency)

        // Okresy: `3 dni + 12 h`, `2 tygodnie * 3`.
        case (.duration(let x, let unit), .duration(let y, let other)):
            let y = try other.convert(y, to: unit)
            switch op {
            case .add, .subtract, .modulo: return .duration(try apply(op, x, y), unit)
            case .divide: return Value(try apply(op, x, y))
            default: throw CalcError.typeMismatch
            }
        case (.duration(let x, let unit), .number(let y, _)):
            guard [.add, .subtract, .multiply, .divide].contains(op) else { throw CalcError.typeMismatch }
            return .duration(try apply(op, x, y), unit)
        case (.number(let x, _), .duration(let y, let unit)):
            guard [.add, .multiply].contains(op) else { throw CalcError.typeMismatch }
            return .duration(try apply(op, x, y), unit)

        // Miary i wagi: `2 kg + 50 dag`, `5 m * 4 m`, `3 km / 1500 m`.
        case (.measure(let x, let unit), .measure(let y, let other)):
            if op == .multiply, let area = unit.squared, other.dimension == .length {
                return .measure(try apply(op, x, try other.convert(y, to: unit)), area)
            }
            let y = try other.convert(y, to: unit)
            switch op {
            case .add, .subtract, .modulo: return .measure(try apply(op, x, y), unit)
            case .divide: return Value(try apply(op, x, y))
            default: throw CalcError.typeMismatch
            }
        case (.measure(let x, let unit), .number(let y, _)):
            guard [.add, .subtract, .multiply, .divide].contains(op) else { throw CalcError.typeMismatch }
            return .measure(try apply(op, x, y), unit)
        case (.number(let x, _), .measure(let y, let unit)):
            guard [.add, .multiply].contains(op) else { throw CalcError.typeMismatch }
            return .measure(try apply(op, x, y), unit)

        // Daty: `dziś + 7 dni`, `25.12.2026 - dziś`.
        case (.date(let date, let hasTime), .duration(let n, let unit)):
            guard op == .add || op == .subtract else { throw CalcError.typeMismatch }
            return try add(op == .add ? n : -n, unit, to: date, hasTime: hasTime, calendar: context.calendar)
        case (.duration(let n, let unit), .date(let date, let hasTime)):
            guard op == .add else { throw CalcError.typeMismatch }
            return try add(n, unit, to: date, hasTime: hasTime, calendar: context.calendar)
        case (.date(let x, let xHasTime), .date(let y, let yHasTime)):
            guard op == .subtract else { throw CalcError.typeMismatch }
            return try difference(x, y, withTime: xHasTime || yHasTime, calendar: context.calendar)

        default:
            throw CalcError.typeMismatch
        }
    }

    private static func apply(_ op: BinaryOperator, _ a: Decimal, _ b: Decimal) throws -> Decimal {
        switch op {
        case .add: return try DecimalMath.checked(a + b)
        case .subtract: return try DecimalMath.checked(a - b)
        case .multiply: return try DecimalMath.checked(a * b)
        case .divide: return try DecimalMath.divide(a, b)
        case .modulo: return try DecimalMath.modulo(a, b)
        case .power: return try DecimalMath.power(a, b)
        case .bitAnd: return Decimal(try DecimalMath.toInt64(a) & DecimalMath.toInt64(b))
        case .bitOr: return Decimal(try DecimalMath.toInt64(a) | DecimalMath.toInt64(b))
        case .bitXor: return Decimal(try DecimalMath.toInt64(a) ^ DecimalMath.toInt64(b))
        case .shiftLeft, .shiftRight:
            let shift = try DecimalMath.toInt64(b)
            guard (0...63).contains(shift) else { throw CalcError.overflow }
            let x = try DecimalMath.toInt64(a)
            return Decimal(op == .shiftLeft ? x << shift : x >> shift)
        }
    }

    // MARK: - Kalendarz

    private static func date(year: Int, month: Int, day: Int, calendar: Calendar) throws -> Value {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components
        else { throw CalcError.invalidDate }
        return .date(date, hasTime: false)
    }

    /// Całe dni, tygodnie, miesiące i lata dodajemy kalendarzowo (poprawnie przy zmianie czasu
    /// i końcach miesięcy: 31.01 + 1 miesiąc = 28.02). Resztę – jako sekundy.
    private static func add(_ amount: Decimal, _ unit: TimeUnit, to date: Date, hasTime: Bool, calendar: Calendar) throws -> Value {
        let calendarStep: (Calendar.Component, Int)? = switch unit {
        case .day: (.day, 1)
        case .week: (.day, 7)
        case .month: (.month, 1)
        case .year: (.year, 1)
        default: nil
        }

        if let (component, multiplier) = calendarStep, DecimalMath.isInteger(amount) {
            let count = try DecimalMath.toInt(amount) * multiplier
            guard let result = calendar.date(byAdding: component, value: count, to: date) else { throw CalcError.invalidDate }
            return .date(result, hasTime: hasTime)
        }

        let seconds = try unit.convert(amount, to: .second)
        return .date(date.addingTimeInterval(DecimalMath.toDouble(seconds)), hasTime: true)
    }

    private static func difference(_ a: Date, _ b: Date, withTime: Bool, calendar: Calendar) throws -> Value {
        if !withTime, let days = calendar.dateComponents([.day], from: b, to: a).day {
            return .duration(Decimal(days), .day)
        }
        let hours = try DecimalMath.fromDouble(a.timeIntervalSince(b) / 3600, "różnica dat")
        return .duration(hours, .hour)
    }
}
