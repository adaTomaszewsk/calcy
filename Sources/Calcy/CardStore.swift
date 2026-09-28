import AppKit
import Foundation
import Observation

/// Karty – niezależne notatniki. Każda to osobny plik w ~/Library/Application Support/Calcy/karty.
@MainActor
@Observable
final class CardStore {
    struct Card: Identifiable, Equatable {
        /// Numer karty – stały, wyznacza kolejność i początek nazwy pliku.
        let number: Int
        /// Nazwa nadana przez użytkownika; `nil` – nazwa automatyczna.
        var customTitle: String?
        var text: String

        var id: Int { number }

        /// Plik: `003.txt` albo z nazwą: `003 Zakupy.txt`.
        var fileName: String {
            let prefix = String(format: "%03d", number)
            return customTitle.map { "\(prefix) \($0).txt" } ?? "\(prefix).txt"
        }

        var title: String {
            customTitle ?? automaticTitle
        }

        /// Pierwszy nagłówek (`# Zakupy`), a gdy go brak – pierwsza niepusta linia.
        var automaticTitle: String {
            let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            if let header = lines.first(where: { $0.hasPrefix("#") }) {
                let name = header.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
            guard let first = lines.first(where: { !$0.isEmpty }) else { return "Nowa karta" }
            return first.count > 28 ? String(first.prefix(27)) + "…" : first
        }

        var isEmpty: Bool {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private(set) var cards: [Card] = []
    private(set) var selectedIndex = 0
    /// Kierunek ostatniego przełączenia: 1 – w prawo (następna), -1 – w lewo. Steruje animacją.
    private(set) var direction = 1

    @ObservationIgnored private let directory: URL
    /// Folder testowy (`-cardsDirectory`) nie zapisuje wybranej karty w ustawieniach użytkownika.
    @ObservationIgnored private let isTestDirectory: Bool
    private static let selectionKey = "selectedCard"

    var selected: Card { cards[selectedIndex] }

    init() {
        let base = URL.applicationSupportDirectory.appending(path: "Calcy", directoryHint: .isDirectory)
        // `-cardsDirectory <ścieżka>` w argumentach uruchomienia używa innego folderu (przydatne do testów).
        let override = UserDefaults.standard.string(forKey: "cardsDirectory")
        directory = override.map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? base.appending(path: "karty", directoryHint: .isDirectory)
        isTestDirectory = override != nil
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        load()
        if cards.isEmpty {
            // Pierwsze uruchomienie z kartami: dotychczasowy notatnik staje się pierwszą kartą.
            let legacy = base.appending(path: "notatnik.txt")
            let first = directory.appending(path: Card(number: 1, text: "").fileName)
            if override == nil, FileManager.default.fileExists(atPath: legacy.path) {
                try? FileManager.default.moveItem(at: legacy, to: first)
            } else {
                try? Self.welcomeText.write(to: first, atomically: true, encoding: .utf8)
            }
            load()
        }
        if cards.isEmpty {
            cards = [Card(number: 1, text: "")]
        }
        let saved = UserDefaults.standard.string(forKey: Self.selectionKey).flatMap { Int($0.prefix(while: \.isNumber)) }
        selectedIndex = cards.firstIndex { $0.number == saved } ?? 0
    }

    // MARK: - Edycja

    /// Zapisuje tekst konkretnej karty. Po numerze, nie „bieżącej” – w trakcie animacji
    /// zmiany karty stary edytor może jeszcze dostać zmianę i nie może trafić do nowej karty.
    func updateText(ofCard number: Int, to text: String) {
        guard let index = cards.firstIndex(where: { $0.number == number }) else { return }
        cards[index].text = text
        save(cards[index])
    }

    func select(_ index: Int) {
        guard cards.indices.contains(index), index != selectedIndex else { return }
        direction = index > selectedIndex ? 1 : -1
        let target = cards[index].number
        isRenaming = false
        isConfirmingDelete = false
        removeSelectedIfEmpty()
        selectedIndex = cards.firstIndex { $0.number == target } ?? 0
        rememberSelection()
    }

    func selectNext() { select(selectedIndex + 1) }
    func selectPrevious() { select(selectedIndex - 1) }

    // MARK: - Nazwy

    /// Czy nagłówek jest właśnie w trybie edycji nazwy (⌘R lub kliknięcie).
    var isRenaming = false

    /// Nadaje bieżącej karcie nazwę; pusta nazwa przywraca automatyczną (z nagłówka).
    func renameSelected(_ title: String) {
        let cleaned = String(
            title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(40)
        )
        let newTitle = cleaned.isEmpty || cleaned == selected.automaticTitle ? nil : cleaned
        guard newTitle != selected.customTitle else { return }

        let oldURL = url(for: selected)
        cards[selectedIndex].customTitle = newTitle
        do {
            try FileManager.default.moveItem(at: oldURL, to: url(for: selected))
        } catch {
            NSLog("Calcy: nie udało się zmienić nazwy karty: \(error)")
            save(selected)
            try? FileManager.default.removeItem(at: oldURL)
        }
    }

    /// Nowa pusta karta na końcu. Jeśli bieżąca jest pusta – nie tworzy kolejnej.
    func addCard() {
        guard !selected.isEmpty else { return }
        let next = (cards.map(\.number).max() ?? 0) + 1
        let card = Card(number: next, text: "")
        save(card)
        cards.append(card)
        select(cards.count - 1)
    }

    /// Kosz w stopce czeka na potwierdzenie („Usuń kartę?”).
    var isConfirmingDelete = false

    /// Kosz: pusta karta znika od razu, karta z treścią wymaga potwierdzenia.
    func requestDelete() {
        if selected.isEmpty {
            if cards.count > 1 { deleteSelected() }
        } else {
            isConfirmingDelete = true
        }
    }

    /// Usuwa bieżącą kartę. Jeśli to jedyna karta – zastępuje ją nową, pustą.
    func deleteSelected() {
        isConfirmingDelete = false
        isRenaming = false
        try? FileManager.default.removeItem(at: url(for: selected))
        direction = -1
        if cards.count == 1 {
            let fresh = Card(number: selected.number + 1, text: "")
            save(fresh)
            cards = [fresh]
            selectedIndex = 0
        } else {
            cards.remove(at: selectedIndex)
            selectedIndex = min(selectedIndex, cards.count - 1)
        }
        rememberSelection()
    }

    // MARK: - Pliki

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        cards = files
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url -> Card? in
                let name = url.deletingPathExtension().lastPathComponent
                guard let number = Int(name.prefix(while: \.isNumber)) else { return nil }
                let title = name.drop(while: \.isNumber).trimmingCharacters(in: .whitespaces)
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return Card(number: number, customTitle: title.isEmpty ? nil : title, text: text)
            }
            .sorted { $0.number < $1.number }
    }

    private func save(_ card: Card) {
        do {
            try card.text.write(to: url(for: card), atomically: true, encoding: .utf8)
        } catch {
            NSLog("Calcy: nie udało się zapisać karty \(card.fileName): \(error)")
        }
    }

    private func removeSelectedIfEmpty() {
        guard cards.count > 1, selected.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: selected))
        cards.remove(at: selectedIndex)
    }

    private func rememberSelection() {
        guard !isTestDirectory else { return }
        UserDefaults.standard.set(String(selected.number), forKey: Self.selectionKey)
    }

    private func url(for card: Card) -> URL {
        directory.appending(path: card.fileName)
    }

    private static let welcomeText = """
    # Witaj w Calcy!
    // Pisz obliczenia po lewej – wyniki pojawiają się po prawej.
    // Kliknij wynik, żeby go skopiować.

    # Zmienne
    nocleg = 4 * 320
    paliwo = 850 / 100 * 7 * 6,5
    razem = nocleg + paliwo
    Na osobę: razem / 3

    # Programista
    0xFF + 0b1010
    1280 in hex
    255 jako bin
    0xF0 | 0x0F
    1 << 10

    # Daty
    dziś + 7 dni
    today + 3 weeks
    urlop = 1.10.2026
    urlop - dziś
    Święta za: 25.12.2026 - dziś in weeks
    teraz + 90 min

    # Waluty (kursy NBP)
    100 USD w PLN
    50 € + 20 zł
    $30 * 3 na zł
    £10 jako euro

    # Bloki
    120
    80
    45,5
    suma
    średnia
    prev * 2

    # Funkcje
    sqrt(2)
    round(pi; 4)
    max(3; 9; 4)
    """
}
