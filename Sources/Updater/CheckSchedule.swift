import Foundation

/// Pilnuje, jak często wolno pytać GitHuba o nowe wydanie.
///
/// Bez logowania GitHub pozwala na 60 zapytań na godzinę z jednego adresu IP, więc:
/// sprawdzamy raz na 6 godzin, po błędzie sieci czekamy coraz dłużej,
/// a przy odpowiedzi „limit wyczerpany” czekamy dokładnie tyle, ile każe serwer.
public struct CheckSchedule: Sendable, Equatable {
    public var interval: TimeInterval
    public var lastCheck: Date?
    /// Wcześniejsze odpytanie jest zablokowane do tego momentu (limit lub kolejne błędy).
    public var blockedUntil: Date?
    public var failureCount = 0

    public static let defaultInterval: TimeInterval = 6 * 3600
    public static let minimumBackoff: TimeInterval = 60
    public static let maximumBackoff: TimeInterval = 6 * 3600

    public init(interval: TimeInterval = defaultInterval, lastCheck: Date? = nil, blockedUntil: Date? = nil) {
        self.interval = interval
        self.lastCheck = lastCheck
        self.blockedUntil = blockedUntil
    }

    /// - Parameter manual: kliknięcie „Sprawdź teraz” omija odstęp, ale nie limit serwera.
    public func allowsCheck(now: Date, manual: Bool = false) -> Bool {
        if let blockedUntil, now < blockedUntil { return false }
        if manual { return true }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    public mutating func recordSuccess(now: Date) {
        lastCheck = now
        blockedUntil = nil
        failureCount = 0
    }

    public mutating func recordFailure(now: Date) {
        lastCheck = now
        failureCount += 1
        let backoff = min(Self.minimumBackoff * pow(2, Double(failureCount - 1)), Self.maximumBackoff)
        blockedUntil = now.addingTimeInterval(backoff)
    }

    /// Odpowiedź 403/429 z nagłówkiem `X-RateLimit-Reset` (albo `Retry-After`).
    public mutating func recordRateLimit(now: Date, resetAt: Date?, retryAfter: TimeInterval?) {
        lastCheck = now
        failureCount = 0
        let fallback = now.addingTimeInterval(Self.maximumBackoff)
        blockedUntil = resetAt ?? retryAfter.map { now.addingTimeInterval($0) } ?? fallback
    }

    /// Kiedy najwcześniej warto spróbować ponownie.
    public func nextCheck(now: Date) -> Date {
        let afterInterval = lastCheck?.addingTimeInterval(interval) ?? now
        return max(afterInterval, blockedUntil ?? now)
    }
}
