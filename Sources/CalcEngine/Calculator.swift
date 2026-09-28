import Foundation

public enum LineKind: Sendable, Equatable {
    case empty
    case header
    case comment
    case expression
    case assignment(name: String)
}

public struct LineResult: Sendable, Equatable {
    public var kind: LineKind
    public var value: Value?
    public var error: CalcError?
}

/// Liczy cały dokument linia po linii. Każda linia widzi zmienne zdefiniowane nad nią.
public struct Calculator: Sendable {
    public var calendar: Calendar
    /// Kursy walut. Bez nich działają tylko obliczenia w jednej walucie.
    public var rates: ExchangeRates?

    public init(calendar: Calendar = .current, rates: ExchangeRates? = nil) {
        self.calendar = calendar
        self.rates = rates
    }

    /// Wbudowane funkcje i słowa kluczowe – do podpowiedzi w edytorze.
    public static var builtinWords: [String] { Keywords.completions }

    public func evaluate(_ text: String, now: Date = Date()) -> [LineResult] {
        evaluate(lines: text.components(separatedBy: "\n"), now: now)
    }

    public func evaluate(lines: [String], now: Date = Date()) -> [LineResult] {
        var context = Context(now: now, calendar: calendar, rates: rates)
        return lines.map { evaluate(line: $0, context: &context) }
    }

    private func evaluate(line: String, context: inout Context) -> LineResult {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            context.block = []
            return LineResult(kind: .empty)
        }
        if trimmed.hasPrefix("#") {
            context.block = []
            return LineResult(kind: .header)
        }

        let body = Self.stripLabel(Self.stripComment(trimmed))
        if body.isEmpty {
            return LineResult(kind: .comment)
        }

        do {
            let statement = try Parser.parse(try Lexer.tokenize(body))
            let kind: LineKind
            var value: Value
            switch statement {
            case .expression(let expression, let conversion):
                kind = .expression
                value = try Self.evaluate(expression, conversion, in: context)
            case .assignment(let name, let expression, let conversion):
                kind = .assignment(name: name)
                value = try Self.evaluate(expression, conversion, in: context)
                context.variables[name] = value
            }
            context.previous = value
            context.block.append(value)
            return LineResult(kind: kind, value: value)
        } catch let error as CalcError {
            return LineResult(kind: .expression, error: error)
        } catch {
            return LineResult(kind: .expression, error: .undefined("\(error)"))
        }
    }

    private static func evaluate(_ expression: Expression, _ conversion: Conversion?, in context: Context) throws -> Value {
        let value = try Evaluator.evaluate(expression, in: context)
        if let conversion {
            return try Evaluator.convert(value, to: conversion, in: context)
        }
        if case .number = expression, case .number(let n, _) = value {
            // Samotny literał (`0xFF`) pokazujemy dziesiętnie – po to się go wpisuje.
            return .number(n, .decimal)
        }
        return value
    }

    /// Wszystko od `//` do końca linii to komentarz.
    static func stripComment(_ line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    /// Etykieta na początku linii: `Nocleg: 4 * 320` → `4 * 320`.
    static func stripLabel(_ line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return line }
        let label = line[..<colon]
        guard label.contains(where: \.isLetter), !label.contains(where: { "=()".contains($0) }) else { return line }
        return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }
}

extension LineResult {
    init(kind: LineKind) {
        self.init(kind: kind, value: nil, error: nil)
    }
}
