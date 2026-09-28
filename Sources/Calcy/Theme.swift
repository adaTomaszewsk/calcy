import AppKit
import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "theme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Systemowy"
        case .light: "Jasny"
        case .dark: "Ciemny"
        }
    }

    static var current: Theme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Theme.init) ?? .system
    }

    @MainActor
    func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Kolory edytora – osobne dla jasnego i ciemnego motywu, rozwiązywane w chwili rysowania.
@MainActor
enum Palette {
    static let background = dynamic(light: 0xFFFFFF, dark: 0x1E1F24)
    static let text = dynamic(light: 0x1D1D1F, dark: 0xE4E4E7)
    static let caret = dynamic(light: 0x1D1D1F, dark: 0xFFCC66)
    static let secondary = dynamic(light: 0x8A8A8E, dark: 0x8B8E98)
    static let comment = dynamic(light: 0xB0B0B5, dark: 0x5F6370)
    static let currentLine = dynamic(light: 0xF6F6F8, dark: 0x24262C)
    static let selection = dynamic(light: 0xDCE7FB, dark: 0x34405A)
    static let scrollKnob = dynamic(light: 0xC9C9CF, dark: 0x3C3F48)
    static let hoverPill = dynamic(light: 0xEEF3FD, dark: 0x2A3246)
    static let copiedPill = dynamic(light: 0xE3F6EA, dark: 0x1F3A2A)
    static let chromeText = dynamic(light: 0x9A9AA0, dark: 0x6E717C)
    static let control = dynamic(light: 0xF1F1F4, dark: 0x2A2C33)
    static let controlHover = dynamic(light: 0xE6E6EB, dark: 0x33363E)

    static let number = dynamic(light: 0xC65A00, dark: 0xFFB86C)
    static let variable = dynamic(light: 0x8E3DC8, dark: 0xC792EA)
    static let keyword = dynamic(light: 0xC2185B, dark: 0xFF79C6)
    static let unit = dynamic(light: 0x00838F, dark: 0x7FDBCA)

    static let result = dynamic(light: 0x0A66D8, dark: 0x82AAFF)
    static let assignedResult = dynamic(light: 0x8A8A8E, dark: 0x8B8E98)
    static let danger = dynamic(light: 0xE5484D, dark: 0xE5484D)
    static let copiedResult = dynamic(light: 0x1E9E4A, dark: 0x6FE39A)

    private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return color(isDark ? dark : light)
        }
    }

    private nonisolated static func color(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Menu Widok → Motyw (z opcją „Systemowy”).
struct ThemeCommands: Commands {
    @AppStorage(Theme.storageKey) private var theme: Theme = .system

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Picker("Motyw", selection: $theme) {
                ForEach(Theme.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
        }
    }
}
