import Foundation
import Testing
@testable import CalcEngine

private let formatter = ValueFormatter(decimalSeparator: ",", groupingSeparator: " ")

private func results(_ text: String) -> [String?] {
    Calculator().evaluate(text).map { $0.value.map { formatter.format($0) } }
}

private func result(_ text: String) -> String? {
    results(text).last ?? nil
}

@Suite("Arytmetyka")
struct ArithmeticTests {
    @Test(arguments: [
        ("2 + 3 * (4 - 1)", "11"),
        ("10 / 4", "2,5"),
        ("2^3^2", "512"),
        ("2 ** 10", "1024"),
        ("-2^2", "-4"),
        ("2^-1", "0,5"),
        ("-(3 + 4) * 2", "-14"),
        ("7 mod 3", "1"),
        ("-7 mod 3", "2"),
        ("1/3", "0,3333333333"),
        ("0.1 + 0.2", "0,3"),
        ("3,5 * 2", "7"),
        (".5 + 1", "1,5"),
        ("1_000_000", "1 000 000"),
        ("1e3 + 2.5E-1", "1000,25"),
        ("6 × 7 ÷ 2 − 1", "20"),
        ("2^100", "1 267 650 600 228 229 401 496 703 205 376"),
    ])
    func evaluates(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func divisionByZeroIsError() {
        let line = Calculator().evaluate("1 / 0")[0]
        #expect(line.value == nil)
        #expect(line.error == .divisionByZero)
    }

    @Test(arguments: ["2 +", "(1 + 2", "3 3", "1 % 2", "@"])
    func malformedInputHasNoValue(input: String) {
        #expect(result(input) == nil)
    }
}

@Suite("Zmienne i dokument")
struct DocumentTests {
    @Test func variablesFlowDownTheDocument() {
        #expect(results("a = 5\nb = a * 2\nb + 1") == ["5", "10", "11"])
    }

    @Test func reassignmentAffectsOnlyLinesBelow() {
        #expect(results("x = 1\nx\nx = 2\nx") == ["1", "1", "2", "2"])
    }

    @Test func variableNamesArePolishFriendly() {
        #expect(result("cena_brutto = 123\nzniżka = 23\ncena_brutto - zniżka") == "100")
    }

    @Test func unknownVariableIsError() {
        #expect(Calculator().evaluate("foo + 1")[0].error == .unknownVariable("foo"))
    }

    @Test func reservedNamesCannotBeAssigned() {
        #expect(Calculator().evaluate("sum = 5")[0].error == .reservedName("sum"))
    }

    @Test func previousResult() {
        #expect(results("10\nprev * 2\npoprzedni + 1") == ["10", "20", "21"])
    }

    @Test func sumAndAverageOfBlock() {
        #expect(result("10\n20\n30\nsum") == "60")
        #expect(result("10\n20\n30\nśrednia") == "20")
        #expect(result("100\n\n1\n2\nsuma") == "3")
        #expect(result("100\n# Nowa sekcja\n5\ntotal") == "5")
    }

    @Test func commentsHeadersAndLabels() {
        #expect(results("# Budżet\n// sam komentarz\n5 * 2 // dziesięć\nNocleg: 4 * 320") == [nil, nil, "10", "1280"])
    }

    @Test func plainTextLineHasNoValue() {
        #expect(result("Zakupy na weekend") == nil)
    }

    @Test func assignmentLinesAreMarked() {
        #expect(Calculator().evaluate("a = 1")[0].kind == .assignment(name: "a"))
    }
}

@Suite("Tryb programisty")
struct ProgrammerTests {
    @Test(arguments: [
        ("0xFF + 0b1010", "265"),
        ("0o17", "15"),
        ("255 in hex", "0xFF"),
        ("255 jako bin", "0b11111111"),
        ("0xFF to dec", "255"),
        ("64 w oct", "0o100"),
        ("-255 as hex", "-0xFF"),
        ("0xF0 | 0x0F", "0xFF"),
        ("0xFF & 0x0F", "0xF"),
        ("6 xor 3", "5"),
        ("1 << 10", "1024"),
        ("1024 >> 3", "128"),
        ("~0", "-1"),
        ("0xFFFF_FFFF", "4 294 967 295"),
        ("2.5 in hex", "2,5"),
        ("0xFF", "255"),
        ("0x10 + 0x01", "0x11"),
        ("2^70", "1 180 591 620 717 411 303 424"),
    ])
    func evaluates(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func bitwiseRequiresIntegers() {
        #expect(Calculator().evaluate("2.5 & 1")[0].error == .notAnInteger)
    }

    @Test func conversionOnAssignment() {
        #expect(results("mask = 0b1111 in hex\nmask") == ["0xF", "0xF"])
    }

    @Test func conversionWordStillUsableAsVariable() {
        #expect(result("w = 3\nw * 2") == "6")
    }
}

@Suite("Funkcje i stałe")
struct FunctionTests {
    @Test(arguments: [
        ("sqrt(16)", "4"),
        ("pierwiastek(2)", "1,4142135624"),
        ("max(1; 7; 3)", "7"),
        ("min(4, 2)", "2"),
        ("round(3.14159; 2)", "3,14"),
        ("zaokrąglij(2.5)", "3"),
        ("floor(-1.5)", "-2"),
        ("sufit(1.2)", "2"),
        ("abs(-5)", "5"),
        ("silnia(5)", "120"),
        ("log(1000)", "3"),
        ("log(8; 2)", "3"),
        ("sin(pi)", "0"),
        ("cos(0)", "1"),
        ("pow(2; 8)", "256"),
        ("2 * pi", "6,2831853072"),
    ])
    func evaluates(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func domainErrors() {
        #expect(result("sqrt(-1)") == nil)
        #expect(result("ln(0)") == nil)
        #expect(Calculator().evaluate("nope(1)")[0].error == .unknownFunction("nope"))
    }
}

@Suite("Formatowanie")
struct FormatterTests {
    @Test func groupsFromFiveDigits() {
        #expect(formatter.format(Value(1280)) == "1280")
        #expect(formatter.format(Value(12800)) == "12 800")
        #expect(formatter.format(Value(Decimal(string: "-1234567.5")!)) == "-1 234 567,5")
    }

    @Test func ungroupedForCopying() {
        #expect(formatter.format(Value(1234567), grouping: false) == "1234567")
    }

    @Test func noNegativeZero() {
        #expect(formatter.format(Value(Decimal(string: "-0.00000000000001")!)) == "0")
    }
}

@Suite("Kolorowanie")
struct HighlighterTests {
    private func kinds(_ line: String, variables: Set<String> = []) -> [String: HighlightKind] {
        let ns = line as NSString
        var map: [String: HighlightKind] = [:]
        for h in Highlighter.highlight(line, variables: variables) {
            map[ns.substring(with: h.range)] = h.kind
        }
        return map
    }

    @Test func classifiesTokens() {
        let k = kinds("cena = sqrt(zniżka) + 5 USD in hex // uwaga", variables: ["zniżka"])
        #expect(k["cena"] == .variable)
        #expect(k["zniżka"] == .variable)
        #expect(k["sqrt"] == .function)
        #expect(k["5"] == .number)
        #expect(k["USD"] == .unit)
        #expect(k["in"] == .keyword)
        #expect(k["hex"] == .keyword)
        #expect(k["+"] == .symbol)
        #expect(k["// uwaga"] == .comment)
    }

    @Test func headerAndLabel() {
        #expect(kinds("# Budżet") == ["# Budżet": .header])
        let k = kinds("Święta za: 25.12.2026 - dziś")
        #expect(k["Święta za:"] == .label)
        #expect(k["25.12.2026"] == .number)
        #expect(k["dziś"] == .keyword)
    }

    @Test func utf16RangesWithEmoji() {
        let line = "🎉 x = 5"
        let h = Highlighter.highlight(line, variables: ["x"])
        #expect(h.contains { (line as NSString).substring(with: $0.range) == "x" && $0.kind == .variable })
    }

    @Test func toleratesInvalidInput() {
        #expect(kinds("5 @ 3")["3"] == .number)
    }
}
