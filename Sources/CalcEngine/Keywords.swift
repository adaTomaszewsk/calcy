import Foundation

/// Słowa kluczowe – każde w wariancie angielskim i polskim. Porównywane bez rozróżniania wielkości liter.
enum Keywords {
    static let conversion: Set<String> = ["in", "as", "to", "jako", "na", "w"]

    /// Cele konwersji systemu liczbowego. Waluty i jednostki czasu są w `Currency` i `TimeUnit`.
    static let radix: [String: Radix] = [
        "dec": .decimal, "decimal": .decimal, "dziesiętnie": .decimal, "dziesietnie": .decimal,
        "hex": .hexadecimal, "hexadecimal": .hexadecimal, "szesnastkowo": .hexadecimal,
        "bin": .binary, "binary": .binary, "binarnie": .binary, "dwójkowo": .binary, "dwojkowo": .binary,
        "oct": .octal, "octal": .octal, "ósemkowo": .octal, "osemkowo": .octal,
    ]

    static let previous: Set<String> = ["prev", "previous", "poprz", "poprzedni", "poprzednia"]
    static let sum: Set<String> = ["sum", "total", "suma"]
    static let average: Set<String> = ["avg", "average", "średnia", "srednia"]

    static let today: Set<String> = ["today", "dziś", "dzis", "dzisiaj"]
    static let now: Set<String> = ["now", "teraz"]
    static let tomorrow: Set<String> = ["tomorrow", "jutro"]
    static let yesterday: Set<String> = ["yesterday", "wczoraj"]

    static let xor: Set<String> = ["xor"]
    static let modulo: Set<String> = ["mod"]

    static let constants: [String: Decimal] = [
        "pi": Decimal(string: "3.14159265358979323846264338327950288")!,
        "π": Decimal(string: "3.14159265358979323846264338327950288")!,
        "e": Decimal(string: "2.71828182845904523536028747135266250")!,
    ]

    /// Słowa podpowiadane po wciśnięciu Tab (oprócz zmiennych z dokumentu).
    static let completions: [String] = [
        "dziś", "dzisiaj", "today", "jutro", "tomorrow", "wczoraj", "yesterday", "teraz", "now",
        "suma", "sum", "total", "średnia", "avg", "average", "poprzedni", "prev",
        "pi", "xor", "mod",
        "sqrt", "pierwiastek", "cbrt", "abs", "round", "zaokrąglij", "floor", "podłoga", "ceil", "sufit",
        "min", "max", "sin", "cos", "tan", "asin", "acos", "atan", "ln", "log", "log2", "exp",
        "pow", "potęga", "fact", "silnia",
        "hex", "bin", "oct", "dec", "szesnastkowo", "binarnie", "ósemkowo", "dziesiętnie",
    ]

    /// Nazwy, których nie można użyć jako zmiennej.
    static func isReserved(_ name: String) -> Bool {
        let key = name.lowercased()
        return previous.contains(key) || sum.contains(key) || average.contains(key)
            || xor.contains(key) || modulo.contains(key)
    }
}
