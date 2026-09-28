import Foundation

public enum HighlightKind: Sendable, Equatable {
    case number
    case variable
    case function
    case keyword
    case unit
    case symbol
    case label
    case comment
    case header
}

public struct Highlight: Sendable, Equatable {
    /// Zakres w jednostkach UTF-16 (jak `NSRange`) względem początku linii.
    public var range: NSRange
    public var kind: HighlightKind
}

/// Kolorowanie składni jednej linii. Działa też dla linii niepoprawnych albo niedokończonych.
public enum Highlighter {
    public static func highlight(_ line: String, variables: Set<String>) -> [Highlight] {
        let chars = Array(line)
        // Przesunięcia UTF-16 każdego znaku – NSTextView liczy w UTF-16, a lexer w znakach.
        var offsets = [0]
        for c in chars { offsets.append(offsets.last! + c.utf16.count) }
        func range(_ r: Range<Int>) -> NSRange {
            NSRange(location: offsets[r.lowerBound], length: offsets[r.upperBound] - offsets[r.lowerBound])
        }

        guard let firstNonSpace = chars.firstIndex(where: { !$0.isWhitespace }) else { return [] }
        if chars[firstNonSpace] == "#" {
            return [Highlight(range: range(firstNonSpace..<chars.count), kind: .header)]
        }

        var highlights: [Highlight] = []
        var bodyEnd = chars.count
        if let comment = (0..<max(chars.count - 1, 0)).first(where: { chars[$0] == "/" && chars[$0 + 1] == "/" }) {
            bodyEnd = comment
            highlights.append(Highlight(range: range(comment..<chars.count), kind: .comment))
        }

        var bodyStart = 0
        let body = String(chars[0..<bodyEnd])
        let stripped = Calculator.stripLabel(body.trimmingCharacters(in: .whitespaces))
        if stripped != body.trimmingCharacters(in: .whitespaces), let colon = chars[0..<bodyEnd].firstIndex(of: ":") {
            bodyStart = colon + 1
            highlights.append(Highlight(range: range(0..<bodyStart), kind: .label))
        }

        let tokens = (try? Lexer.scan(Array(chars[bodyStart..<bodyEnd]), lenient: true)) ?? []
        for (index, item) in tokens.enumerated() {
            let next = index + 1 < tokens.count ? tokens[index + 1].token : .end
            guard let kind = kind(of: item.token, next: next, variables: variables) else { continue }
            let r = (item.range.lowerBound + bodyStart)..<(item.range.upperBound + bodyStart)
            highlights.append(Highlight(range: range(r), kind: kind))
        }
        return highlights
    }

    private static func kind(of token: Token, next: Token, variables: Set<String>) -> HighlightKind? {
        switch token {
        case .number, .date:
            return .number
        case .symbol:
            return .symbol
        case .end:
            return nil
        case .identifier(let word):
            let key = word.lowercased()
            if next == .symbol("("), Function.named(word) != nil { return .function }
            if variables.contains(word) || next == .symbol("=") { return .variable }
            if Quantity.named(word) != nil { return .unit }
            if Keywords.completions.contains(key) || Keywords.conversion.contains(key) || Keywords.radix[key] != nil
                || Keywords.isReserved(word) || Keywords.constants[key] != nil
                || [Keywords.today, Keywords.now, Keywords.tomorrow, Keywords.yesterday].contains(where: { $0.contains(key) }) {
                return .keyword
            }
            return nil
        }
    }
}
