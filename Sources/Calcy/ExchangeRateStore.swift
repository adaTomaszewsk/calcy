import CalcEngine
import Foundation
import Observation

/// Pobiera średnie kursy NBP i trzyma kopię w ~/Library/Application Support/Calcy/kursy.json,
/// żeby waluty działały też bez internetu.
@MainActor
@Observable
final class ExchangeRateStore {
    private(set) var rates: ExchangeRates?
    private(set) var isOffline = false

    /// Wywoływane po pobraniu nowych kursów.
    @ObservationIgnored var onChange: ((ExchangeRates) -> Void)?

    @ObservationIgnored private let cacheURL: URL
    private static let maxAge: TimeInterval = 3 * 3600

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "Calcy", directoryHint: .isDirectory)
        cacheURL = directory.appending(path: "kursy.json")
        if let data = try? Data(contentsOf: cacheURL) {
            rates = try? JSONDecoder().decode(ExchangeRates.self, from: data)
        }
    }

    enum Status {
        case loading, fresh, offline
    }

    var status: Status {
        if isOffline { return .offline }
        return rates == nil ? .loading : .fresh
    }

    /// Krótka etykieta do stopki: `NBP · 18.09.2026`.
    var shortStatusText: String {
        guard let rates else { return isOffline ? "Brak kursów" : "Pobieranie kursów…" }
        return "NBP · " + rates.effectiveDate.split(separator: "-").reversed().joined(separator: ".")
    }

    var statusText: String {
        guard let rates else { return isOffline ? "Brak kursów walut – brak połączenia z NBP" : "Pobieranie kursów walut…" }
        let date = rates.effectiveDate.split(separator: "-").reversed().joined(separator: ".")
        return "Kursy NBP z \(date)" + (isOffline ? " (offline)" : "")
    }

    /// Odświeża kursy co godzinę, jeśli są starsze niż 3 godziny. Kończy się razem z oknem.
    func keepUpdated() async {
        while !Task.isCancelled {
            if rates.map({ Date().timeIntervalSince($0.fetchedAt) > Self.maxAge }) ?? true {
                await refresh()
            }
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    private func refresh() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: ExchangeRates.nbpTableURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let fresh = try ExchangeRates.fromNBP(data, fetchedAt: Date())
            rates = fresh
            isOffline = false
            try? JSONEncoder().encode(fresh).write(to: cacheURL, options: .atomic)
            onChange?(fresh)
        } catch {
            isOffline = true
            NSLog("Calcy: nie udało się pobrać kursów NBP: \(error)")
        }
    }
}
