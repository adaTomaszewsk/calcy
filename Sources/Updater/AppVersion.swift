import Foundation

/// Wersja w formacie `0.1.7` (z opcjonalnym `v` z przodu).
public struct AppVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var components: [Int] = []
        for part in parts {
            // Ucinamy dopiski w rodzaju „1.2.3-beta”.
            let digits = part.prefix { $0.isNumber }
            guard !digits.isEmpty, let value = Int(digits) else { return nil }
            components.append(value)
        }
        self.components = components
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }
}
