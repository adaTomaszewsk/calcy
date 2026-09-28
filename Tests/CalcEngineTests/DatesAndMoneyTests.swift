import Foundation
import Testing
@testable import CalcEngine

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
    return calendar
}()

/// Piątek, 18 września 2026, 12:00 czasu polskiego.
private let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12))!

private let rates = ExchangeRates(
    effectiveDate: "2026-09-18",
    fetchedAt: now,
    pricesInPLN: ["USD": 3.6, "EUR": 4.25, "GBP": 4.9]
)

private let formatter = ValueFormatter(
    decimalSeparator: ",",
    groupingSeparator: " ",
    locale: Locale(identifier: "pl_PL"),
    calendar: calendar
)

private func result(_ text: String, rates: ExchangeRates? = rates, grouping: Bool = true) -> String? {
    let lines = Calculator(calendar: calendar, rates: rates).evaluate(text, now: now)
    return lines.last?.value.map { formatter.format($0, grouping: grouping) }
}

private func date(_ text: String) -> String? {
    result(text, grouping: false)
}

@Suite("Daty")
struct DateTests {
    @Test(arguments: [
        ("dziś", "18.09.2026"),
        ("today", "18.09.2026"),
        ("jutro", "19.09.2026"),
        ("wczoraj", "17.09.2026"),
        ("today + 7 dni", "25.09.2026"),
        ("dziś + 3 tygodnie", "09.10.2026"),
        ("dzisiaj - 1 rok", "18.09.2025"),
        ("today + 2 weeks", "02.10.2026"),
        ("31.01.2026 + 1 miesiąc", "28.02.2026"),
        ("25.12.2026", "25.12.2026"),
        ("1.5.2026", "01.05.2026"),
        ("2026-12-25 + 1 day", "26.12.2026"),
        ("teraz + 2 h", "18.09.2026 14:00"),
        ("now + 90 min", "18.09.2026 13:30"),
        ("dziś + 1,5 dnia", "19.09.2026 12:00"),
        // 25.10.2026 to zmiana czasu – dodawanie dni nie może przesunąć godziny.
        ("24.10.2026 + 2 dni", "26.10.2026"),
    ])
    func dateArithmetic(input: String, expected: String) {
        #expect(date(input) == expected)
    }

    @Test(arguments: [
        ("25.12.2026 - dziś", "98 dni"),
        ("2026-12-24 - 2026-12-23", "1 dzień"),
        ("jutro - wczoraj", "2 dni"),
        ("teraz - dziś", "12 godzin"),
    ])
    func differences(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func longDateFormat() {
        #expect(result("25.12.2026")?.contains("grudnia 2026") == true)
    }

    @Test(arguments: ["31.02.2026", "2026-13-01", "dziś + 1,5 miesiąca", "dziś + dziś", "dziś * 2"])
    func invalid(input: String) {
        #expect(result(input) == nil)
    }

    @Test func dateVariables() {
        #expect(date("start = 1.10.2026\nkoniec = start + 2 tygodnie\nkoniec") == "15.10.2026")
    }
}

@Suite("Okresy")
struct DurationTests {
    @Test(arguments: [
        ("7 dni", "7 dni"),
        ("1 dzień", "1 dzień"),
        ("2 tygodnie in dni", "14 dni"),
        ("3 dni + 12 h", "3,5 dnia"),
        ("1 rok w miesiącach", "12 miesięcy"),
        ("90 min in hours", "1,5 godziny"),
        ("2 tygodnie * 3", "6 tygodni"),
        ("22 h", "22 godziny"),
        ("12 h", "12 godzin"),
        ("5 lat", "5 lat"),
        ("2 lata", "2 lata"),
        ("(25.12.2026 - dziś) in weeks", "14 tygodni"),
        ("1 tydzień / 1 dzień", "7"),
    ])
    func durations(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func monthsToDaysIsInexact() {
        let line = Calculator(calendar: calendar).evaluate("1 rok in days", now: now)[0]
        #expect(line.error == .inexactConversion)
    }

    @Test func minStillWorksAsFunction() {
        #expect(result("min(3; 1)") == "1")
        #expect(result("5 min") == "5 minut")
    }
}

@Suite("Waluty")
struct CurrencyTests {
    @Test(arguments: [
        ("100 USD", "100,00 $"),
        ("10 usd", "10,00 $"),
        ("$100 in PLN", "360,00 zł"),
        ("100 dolarów na zł", "360,00 zł"),
        ("100 zł w EUR", "23,53 €"),
        ("50 € + 20 zł", "54,71 €"),
        ("10 EUR * 3", "30,00 €"),
        ("3 * 10 EUR", "30,00 €"),
        ("100 USD / 4", "25,00 $"),
        ("100 USD / 50 USD", "2"),
        ("$30 + 5", "35,00 $"),
        ("-5 zł", "-5,00 zł"),
        ("£10 jako euro", "11,53 €"),
        ("round(10,567 USD; 1)", "10,60 $"),
        ("max(10 EUR; 40 zł)", "10,00 €"),
        ("12500 zł", "12 500,00 zł"),
    ])
    func money(input: String, expected: String) {
        #expect(result(input) == expected)
    }

    @Test func variablesAndBlocks() {
        #expect(result("cena = 20 USD\ncena * 2 in zł") == "144,00 zł")
        #expect(result("10 zł\n5 zł\nsuma") == "15,00 zł")
        #expect(result("10 zł\n2 EUR\nsuma") == "18,50 zł")
        #expect(result("10 zł\n20 zł\nśrednia") == "15,00 zł")
    }

    @Test func sameCurrencyWorksOffline() {
        #expect(result("5 USD + 5 USD", rates: nil) == "10,00 $")
    }

    @Test func conversionNeedsRates() {
        let line = Calculator(calendar: calendar).evaluate("5 USD in PLN", now: now)[0]
        #expect(line.error == .noExchangeRates)
    }

    @Test func missingRate() {
        let line = Calculator(calendar: calendar, rates: rates).evaluate("5 CHF in PLN", now: now)[0]
        #expect(line.error == .noExchangeRate("CHF"))
    }

    @Test(arguments: ["100 zł in hex", "100 XYZ", "5 USD * 5 USD", "5 USD + 3 dni", "(5 USD) EUR"])
    func invalid(input: String) {
        #expect(result(input) == nil)
    }

    @Test func copyFormatCanBePastedBack() {
        let copied = result("12500,5 zł", grouping: false)
        #expect(copied == "12500,50 zł")
        #expect(result(copied!) == "12 500,50 zł")
    }

    @Test func parsesNBPResponse() throws {
        let json = """
        [{"table":"A","no":"182/A/NBP/2026","effectiveDate":"2026-09-18",
          "rates":[{"currency":"dolar amerykański","code":"USD","mid":3.7998},
                   {"currency":"euro","code":"EUR","mid":4.2611}]}]
        """
        let parsed = try ExchangeRates.fromNBP(Data(json.utf8), fetchedAt: now)
        #expect(parsed.effectiveDate == "2026-09-18")
        #expect(parsed.pricesInPLN["USD"] == Decimal(string: "3.7998"))
        #expect(parsed.pricesInPLN["EUR"] == Decimal(string: "4.2611"))
    }
}
