import Foundation

enum Token: Equatable {
    case number(Decimal, Radix)
    case identifier(String)
    case symbol(String)
    case date(year: Int, month: Int, day: Int)
    case end

    var text: String {
        switch self {
        case .number(let n, _): "\(n)"
        case .identifier(let s), .symbol(let s): s
        case .date(let y, let m, let d): "\(d).\(m).\(y)"
        case .end: "koniec linii"
        }
    }
}

enum Lexer {
    private static let twoCharSymbols: Set<String> = ["**", "<<", ">>"]
    private static let symbolAliases: [Character: String] = [
        "+": "+", "-": "-", "−": "-", "–": "-",
        "*": "*", "×": "*", "·": "*", "/": "/", "÷": "/",
        "^": "^", "&": "&", "|": "|", "~": "~",
        "(": "(", ")": ")", ",": ",", ";": ";", "=": "=", "%": "%",
    ]

    static func tokenize(_ input: String) throws -> [Token] {
        try scan(Array(input), lenient: false).map(\.token)
    }

    /// Tokeny z pozycjami (indeksy znaków). W trybie `lenient` błędne znaki są pomijane –
    /// do kolorowania linii, które nie są (jeszcze) poprawnymi wyrażeniami.
    static func scan(_ chars: [Character], lenient: Bool) throws -> [(token: Token, range: Range<Int>)] {
        var tokens: [(token: Token, range: Range<Int>)] = []
        var i = 0

        while i < chars.count {
            let c = chars[i]
            let start = i
            var token: Token?

            do {
                if c.isWhitespace {
                    i += 1
                } else if isDigit(c), let date = dateLiteral(chars, &i) {
                    token = date
                } else if isDigit(c) || (c == "." && i + 1 < chars.count && isDigit(chars[i + 1])) {
                    token = try number(chars, &i)
                } else if c == "°", i + 1 < chars.count, chars[i + 1].isLetter {
                    // Stopnie: `°C`, `°F`.
                    i += 2
                    token = .identifier(String(chars[start..<i]))
                } else if c == "℃" {
                    token = .identifier("℃")
                    i += 1
                } else if Currency.symbolCharacters.contains(c) {
                    token = .identifier(String(c))
                    i += 1
                } else if c.isLetter || c == "_" {
                    while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" {
                        i += 1
                    }
                    token = .identifier(String(chars[start..<i]))
                } else if i + 1 < chars.count, twoCharSymbols.contains(String([c, chars[i + 1]])) {
                    token = .symbol(String([c, chars[i + 1]]))
                    i += 2
                } else if let symbol = symbolAliases[c] {
                    token = .symbol(symbol)
                    i += 1
                } else {
                    throw CalcError.unexpectedCharacter(c)
                }
            } catch {
                guard lenient else { throw error }
                i = max(i, start + 1)
            }

            if let token {
                tokens.append((token, start..<i))
            }
        }
        return tokens
    }

    private static func isDigit(_ c: Character) -> Bool {
        c >= "0" && c <= "9"
    }

    /// Daty: `25.12.2026` (też `1.5.2026`) oraz ISO `2026-12-25`.
    private static func dateLiteral(_ chars: [Character], _ i: inout Int) -> Token? {
        var j = i
        func readNumber() -> (value: Int, length: Int) {
            let start = j
            while j < chars.count, isDigit(chars[j]) { j += 1 }
            return (Int(String(chars[start..<j])) ?? 0, j - start)
        }
        func consume(_ c: Character) -> Bool {
            guard j < chars.count, chars[j] == c else { return false }
            j += 1
            return true
        }

        let first = readNumber()
        let separator: Character = first.length == 4 ? "-" : "."
        guard (1...2).contains(first.length) || first.length == 4, consume(separator) else { return nil }
        let second = readNumber()
        guard consume(separator) else { return nil }
        let third = readNumber()
        guard j >= chars.count || !(isDigit(chars[j]) || chars[j].isLetter || chars[j] == ".") else { return nil }

        let token: Token
        if separator == "-", second.length == 2, third.length == 2 {
            token = .date(year: first.value, month: second.value, day: third.value)
        } else if separator == ".", (1...2).contains(second.length), third.length == 4 {
            token = .date(year: third.value, month: second.value, day: first.value)
        } else {
            return nil
        }
        i = j
        return token
    }

    private static func prefixedRadix(_ c: Character) -> Radix? {
        switch c {
        case "x", "X": .hexadecimal
        case "b", "B": .binary
        case "o", "O": .octal
        default: nil
        }
    }

    /// Liczby: `42`, `3.5`, `3,5`, `1_000`, `1e3`, `0xFF`, `0b1010`, `0o17`.
    /// Przecinek jest separatorem dziesiętnym tylko wtedy, gdy stoi bezpośrednio między cyframi.
    private static func number(_ chars: [Character], _ i: inout Int) throws -> Token {
        let start = i

        if chars[i] == "0", i + 1 < chars.count, let radix = prefixedRadix(chars[i + 1]) {
            i += 2
            var digits = ""
            while i < chars.count, chars[i].isHexDigit || chars[i] == "_" {
                if chars[i] != "_" { digits.append(chars[i]) }
                i += 1
            }
            guard let value = UInt64(digits, radix: radix.base) else {
                throw CalcError.invalidNumber(String(chars[start..<i]))
            }
            return .number(Decimal(value), radix)
        }

        var text = ""
        func readDigits() {
            while i < chars.count {
                if isDigit(chars[i]) {
                    text.append(chars[i])
                } else if chars[i] != "_" || i + 1 >= chars.count || !isDigit(chars[i + 1]) {
                    break
                }
                i += 1
            }
        }

        readDigits()
        if i + 1 < chars.count, chars[i] == "." || chars[i] == ",", isDigit(chars[i + 1]) {
            text.append(".")
            i += 1
            readDigits()
        }
        if i < chars.count, chars[i] == "e" || chars[i] == "E" {
            var j = i + 1
            var sign = ""
            if j < chars.count, chars[j] == "+" || chars[j] == "-" {
                sign = String(chars[j])
                j += 1
            }
            if j < chars.count, isDigit(chars[j]) {
                text += "e" + sign
                i = j
                readDigits()
            }
        }

        if text.hasPrefix(".") { text = "0" + text }
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw CalcError.invalidNumber(String(chars[start..<i]))
        }
        return .number(value, .decimal)
    }
}
