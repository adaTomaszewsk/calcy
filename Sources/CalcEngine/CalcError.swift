import Foundation

public enum CalcError: Error, Sendable, Equatable, CustomStringConvertible {
    case unexpectedCharacter(Character)
    case invalidNumber(String)
    case unexpectedToken(String)
    case unexpectedEnd
    case unknownVariable(String)
    case unknownFunction(String)
    case wrongArgumentCount(String)
    case reservedName(String)
    case noPreviousResult
    case emptyBlock
    case divisionByZero
    case notAnInteger
    case overflow
    case undefined(String)
    case typeMismatch
    case inexactConversion
    case invalidDate
    case noExchangeRates
    case noExchangeRate(String)

    public var description: String {
        switch self {
        case .unexpectedCharacter(let c): "Nieznany znak „\(c)”"
        case .invalidNumber(let s): "Niepoprawna liczba „\(s)”"
        case .unexpectedToken(let t): "Nieoczekiwane „\(t)”"
        case .unexpectedEnd: "Niedokończone wyrażenie"
        case .unknownVariable(let n): "Nieznana zmienna „\(n)”"
        case .unknownFunction(let n): "Nieznana funkcja „\(n)”"
        case .wrongArgumentCount(let n): "Zła liczba argumentów funkcji „\(n)”"
        case .reservedName(let n): "„\(n)” to słowo zastrzeżone"
        case .noPreviousResult: "Brak poprzedniego wyniku"
        case .emptyBlock: "Brak wartości do policzenia"
        case .divisionByZero: "Dzielenie przez zero"
        case .notAnInteger: "Operacja wymaga liczby całkowitej (64-bit)"
        case .overflow: "Wynik poza zakresem"
        case .undefined(let what): "Wynik nieokreślony: \(what)"
        case .typeMismatch: "Nie można połączyć tych wartości"
        case .inexactConversion: "Miesięcy i lat nie da się dokładnie zamienić na dni"
        case .invalidDate: "Niepoprawna data"
        case .noExchangeRates: "Brak kursów walut (brak internetu?)"
        case .noExchangeRate(let code): "Brak kursu \(code)"
        }
    }
}
