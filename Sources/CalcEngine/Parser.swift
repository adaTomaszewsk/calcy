import Foundation

/// Parser metodą Pratta. Priorytety operatorów (od najniższego):
/// `|` < `xor` < `&` < `<< >>` < `+ -` < `* / mod` < unarne `- ~` < `^ **` (prawostronnie łączny).
struct Parser {
    private let tokens: [Token]
    private var position = 0

    private static let unaryPrecedence = 7

    static func parse(_ tokens: [Token]) throws -> Statement {
        var parser = Parser(tokens: tokens)
        return try parser.statement()
    }

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    private var current: Token { peek(0) }

    private func peek(_ offset: Int) -> Token {
        position + offset < tokens.count ? tokens[position + offset] : .end
    }

    private mutating func advance() {
        position += 1
    }

    private mutating func consume(_ symbol: String) -> Bool {
        guard current == .symbol(symbol) else { return false }
        advance()
        return true
    }

    private mutating func expect(_ symbol: String) throws {
        guard consume(symbol) else { throw unexpected(current) }
    }

    private func unexpected(_ token: Token) -> CalcError {
        token == .end ? .unexpectedEnd : .unexpectedToken(token.text)
    }

    private mutating func statement() throws -> Statement {
        if case .identifier(let name) = current, peek(1) == .symbol("=") {
            guard !Keywords.isReserved(name) else { throw CalcError.reservedName(name) }
            position += 2
            let value = try expression(0)
            let conversion = conversionSuffix()
            guard current == .end else { throw unexpected(current) }
            return .assignment(name: name, value, conversion: conversion)
        }

        let value = try expression(0)
        let conversion = conversionSuffix()
        guard current == .end else { throw unexpected(current) }
        return .expression(value, conversion: conversion)
    }

    /// `… in hex`, `… jako bin`, `… na zł`, `… w dniach` itd.
    private mutating func conversionSuffix() -> Conversion? {
        guard case .identifier(let word) = current, Keywords.conversion.contains(word.lowercased()),
              case .identifier(let target) = peek(1), let conversion = Conversion.named(target)
        else { return nil }
        position += 2
        return conversion
    }

    /// Jednostka po wartości: `5 USD`, `100 zł`, `3 dni`. Słowo przed `(` to wywołanie funkcji (`min(…)`).
    private mutating func unitSuffix(_ expression: Expression) -> Expression {
        guard case .identifier(let word) = current, peek(1) != .symbol("("), let quantity = Quantity.named(word)
        else { return expression }
        advance()
        return .quantity(expression, quantity)
    }

    private func infixOperator(_ token: Token) -> (op: BinaryOperator, precedence: Int, rightAssociative: Bool)? {
        switch token {
        case .symbol("|"): (.bitOr, 1, false)
        case .identifier(let word) where Keywords.xor.contains(word.lowercased()): (.bitXor, 2, false)
        case .symbol("&"): (.bitAnd, 3, false)
        case .symbol("<<"): (.shiftLeft, 4, false)
        case .symbol(">>"): (.shiftRight, 4, false)
        case .symbol("+"): (.add, 5, false)
        case .symbol("-"): (.subtract, 5, false)
        case .symbol("*"): (.multiply, 6, false)
        case .symbol("/"): (.divide, 6, false)
        case .identifier(let word) where Keywords.modulo.contains(word.lowercased()): (.modulo, 6, false)
        case .symbol("^"), .symbol("**"): (.power, 8, true)
        default: nil
        }
    }

    private mutating func expression(_ minPrecedence: Int) throws -> Expression {
        var left = try prefix()
        while let info = infixOperator(current), info.precedence > minPrecedence {
            advance()
            let right = try expression(info.rightAssociative ? info.precedence - 1 : info.precedence)
            left = .binary(info.op, left, right)
        }
        return left
    }

    private mutating func prefix() throws -> Expression {
        let token = current
        switch token {
        case .number(let value, let radix):
            advance()
            return unitSuffix(.number(value, radix))

        case .date(let year, let month, let day):
            advance()
            return .date(year: year, month: month, day: day)

        case .identifier(let symbol) where symbol.count == 1 && Currency.symbolCharacters.contains(Character(symbol)):
            // Symbol waluty przed kwotą: `$100`, `€(2 * 5)`.
            advance()
            guard let currency = Currency.named(symbol) else { throw unexpected(token) }
            return .quantity(try expression(Self.unaryPrecedence), .currency(currency))

        case .identifier(let name):
            advance()
            guard consume("(") else { return unitSuffix(.variable(name)) }
            var arguments: [Expression] = []
            if !consume(")") {
                repeat {
                    arguments.append(try expression(0))
                } while consume(";") || consume(",")
                try expect(")")
            }
            return .call(name, arguments)

        case .symbol("("):
            advance()
            let inner = try expression(0)
            try expect(")")
            return unitSuffix(inner)

        case .symbol("-"):
            advance()
            return .unary(.negate, try expression(Self.unaryPrecedence))

        case .symbol("+"):
            advance()
            return try expression(Self.unaryPrecedence)

        case .symbol("~"):
            advance()
            return .unary(.bitNot, try expression(Self.unaryPrecedence))

        default:
            throw unexpected(token)
        }
    }
}
