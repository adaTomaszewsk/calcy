import Foundation

/// Kursy walut względem złotego (średnie kursy NBP).
public struct ExchangeRates: Sendable, Codable, Equatable {
    /// Dzień, z którego pochodzi tabela NBP (np. `2026-09-18`).
    public var effectiveDate: String
    public var fetchedAt: Date
    /// Cena 1 jednostki waluty w złotych, np. `USD: 3.7998`.
    public var pricesInPLN: [String: Decimal]

    public init(effectiveDate: String, fetchedAt: Date, pricesInPLN: [String: Decimal]) {
        self.effectiveDate = effectiveDate
        self.fetchedAt = fetchedAt
        self.pricesInPLN = pricesInPLN
    }

    func convert(_ amount: Decimal, from source: Currency, to target: Currency) throws -> Decimal {
        if source == target { return amount }
        return try DecimalMath.divide(amount * price(of: source), price(of: target))
    }

    private func price(of currency: Currency) throws -> Decimal {
        if currency == .pln { return 1 }
        guard let price = pricesInPLN[currency.code] else { throw CalcError.noExchangeRate(currency.code) }
        return price
    }
}

extension ExchangeRates {
    /// Endpoint tabeli A (średnie kursy) z API NBP.
    public static let nbpTableURL = URL(string: "https://api.nbp.pl/api/exchangerates/tables/A/?format=json")!

    private struct NBPTable: Decodable {
        struct Rate: Decodable {
            let code: String
            let mid: Decimal
        }
        let effectiveDate: String
        let rates: [Rate]
    }

    /// Odczytuje odpowiedź z `nbpTableURL`.
    public static func fromNBP(_ data: Data, fetchedAt: Date) throws -> ExchangeRates {
        guard let table = try JSONDecoder().decode([NBPTable].self, from: data).first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Pusta odpowiedź NBP"))
        }
        var prices: [String: Decimal] = [:]
        for rate in table.rates {
            prices[rate.code] = DecimalMath.rounded(rate.mid, scale: 6)
        }
        return ExchangeRates(effectiveDate: table.effectiveDate, fetchedAt: fetchedAt, pricesInPLN: prices)
    }
}
