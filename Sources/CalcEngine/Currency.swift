import Foundation

public struct Currency: Sendable, Hashable, Codable {
    public let code: String

    public init(_ code: String) {
        self.code = code
    }

    public static let pln = Currency("PLN")

    /// Symbol pokazywany po kwocie: `12,50 zł`, `12,50 €`, `12,50 CHF`.
    public var symbol: String {
        switch code {
        case "PLN": "zł"
        case "EUR": "€"
        case "USD": "$"
        case "GBP": "£"
        default: code
        }
    }

    /// Znaki walut, które lexer traktuje jak słowa (`$100`, `100 €`).
    static let symbolCharacters: Set<Character> = ["$", "€", "£"]

    /// PLN i waluty z tabeli A NBP. Kody pisane wielkimi literami (`CHF`).
    static let knownCodes: Set<String> = [
        "PLN", "AUD", "BRL", "CAD", "CHF", "CLP", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD", "HUF", "IDR",
        "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK", "NZD", "PHP", "RON", "SEK", "SGD", "THB",
        "TRY", "UAH", "USD", "XDR", "ZAR",
    ]

    /// Popularne kody działają też małymi literami (`100 usd`). Rzadkie – tylko wielkimi,
    /// żeby nie kolidowały ze zmiennymi (np. `try`, `php`).
    private static let lowercaseCodes: Set<String> = [
        "pln", "usd", "eur", "gbp", "chf", "jpy", "czk", "nok", "sek", "dkk", "huf", "uah", "cad", "aud", "cny",
    ]

    private static let aliases: [String: String] = [
        "zł": "PLN", "zl": "PLN", "złoty": "PLN", "złote": "PLN", "złotych": "PLN", "złotówek": "PLN",
        "zloty": "PLN", "zlote": "PLN", "zlotych": "PLN", "złotówkach": "PLN",
        "$": "USD", "dolar": "USD", "dolary": "USD", "dolarów": "USD", "dolarow": "USD", "dolarach": "USD",
        "dollar": "USD", "dollars": "USD",
        "€": "EUR", "euro": "EUR",
        "£": "GBP", "funt": "GBP", "funty": "GBP", "funtów": "GBP", "funtow": "GBP", "funtach": "GBP",
        "pound": "GBP", "pounds": "GBP",
        "frank": "CHF", "franki": "CHF", "franków": "CHF", "frankow": "CHF", "frankach": "CHF",
        "jen": "JPY", "jeny": "JPY", "jenów": "JPY", "jenow": "JPY", "yen": "JPY",
        "hrywna": "UAH", "hrywny": "UAH", "hrywien": "UAH",
    ]

    static func named(_ word: String) -> Currency? {
        let lower = word.lowercased()
        if let code = aliases[lower] { return Currency(code) }
        if knownCodes.contains(word) { return Currency(word) }
        if word == lower, lowercaseCodes.contains(lower) { return Currency(lower.uppercased()) }
        return nil
    }
}
