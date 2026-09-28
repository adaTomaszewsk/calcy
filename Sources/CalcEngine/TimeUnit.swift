import Foundation

public enum TimeUnit: Sendable, Equatable {
    case second, minute, hour, day, week, month, year

    static func named(_ word: String) -> TimeUnit? {
        names[word.lowercased()]
    }

    private static let names: [String: TimeUnit] = {
        var names: [String: TimeUnit] = [:]
        let table: [(TimeUnit, [String])] = [
            (.second, ["s", "sec", "second", "seconds", "sekunda", "sekundy", "sekund", "sekundę", "sekunde", "sekundach"]),
            (.minute, ["min", "minute", "minutes", "minuta", "minuty", "minut", "minutę", "minute", "minutach"]),
            (.hour, ["h", "hr", "hour", "hours", "godz", "godzina", "godziny", "godzin", "godzinę", "godzine", "godzinach"]),
            (.day, ["d", "day", "days", "dzień", "dzien", "dni", "dnia", "dniach"]),
            (.week, ["wk", "week", "weeks", "tydz", "tydzień", "tydzien", "tygodnie", "tygodni", "tygodnia", "tygodniach"]),
            (.month, ["month", "months", "mies", "miesiąc", "miesiac", "miesiące", "miesiace", "miesięcy", "miesiecy",
                      "miesiąca", "miesiaca", "miesiącach", "miesiacach"]),
            (.year, ["y", "yr", "year", "years", "rok", "lata", "lat", "roku", "latach"]),
        ]
        for (unit, words) in table {
            for word in words { names[word] = unit }
        }
        return names
    }()

    /// Długość w sekundach dla jednostek o stałej długości.
    private var seconds: Decimal? {
        switch self {
        case .second: 1
        case .minute: 60
        case .hour: 3600
        case .day: 86_400
        case .week: 604_800
        case .month, .year: nil
        }
    }

    private var months: Decimal? {
        switch self {
        case .month: 1
        case .year: 12
        default: nil
        }
    }

    /// Miesiące i lata mają zmienną długość, więc nie da się ich dokładnie zamienić na dni.
    func convert(_ amount: Decimal, to target: TimeUnit) throws -> Decimal {
        if self == target { return amount }
        if let from = seconds, let to = target.seconds { return amount * from / to }
        if let from = months, let to = target.months { return amount * from / to }
        throw CalcError.inexactConversion
    }

    /// Polska odmiana: 1 dzień, 2 dni, 5 dni, 1,5 dnia.
    func polishName(for amount: Decimal) -> String {
        let forms: (one: String, few: String, many: String, fraction: String) = switch self {
        case .second: ("sekunda", "sekundy", "sekund", "sekundy")
        case .minute: ("minuta", "minuty", "minut", "minuty")
        case .hour: ("godzina", "godziny", "godzin", "godziny")
        case .day: ("dzień", "dni", "dni", "dnia")
        case .week: ("tydzień", "tygodnie", "tygodni", "tygodnia")
        case .month: ("miesiąc", "miesiące", "miesięcy", "miesiąca")
        case .year: ("rok", "lata", "lat", "roku")
        }

        guard DecimalMath.isInteger(amount) else { return forms.fraction }
        guard let n = Int(amount.magnitude.description) else { return forms.many }
        if n == 1 { return forms.one }
        if (2...4).contains(n % 10), !(12...14).contains(n % 100) { return forms.few }
        return forms.many
    }
}
