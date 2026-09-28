import AppKit
import SwiftUI
import Updater

enum SettingsKey {
    static let fontSize = "fontSize"
    static let alwaysOnTop = "alwaysOnTop"
    static let hideDockIcon = "hideDockIcon"

    static let defaultFontSize: Double = 15
    static let fontSizeRange: ClosedRange<Double> = 12...22
}

/// Okno ustawień w stylu aplikacji – z własnym nagłówkiem zamiast systemowego paska.
struct SettingsView: View {
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsKey.defaultFontSize
    @AppStorage(SettingsKey.hideDockIcon) private var hideDockIcon = false
    @State private var launchesAtLogin = AppController.shared.launchesAtLogin
    @State private var checker = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 12) {
                fontCard
                SettingsToggle(
                    title: "Uruchamiaj przy logowaniu",
                    subtitle: "Calcy wystartuje razem z Makiem, więc skrót ⌃⌥C zadziała od razu.",
                    isOn: $launchesAtLogin
                )
                .onChange(of: launchesAtLogin) { _, newValue in
                    AppController.shared.launchesAtLogin = newValue
                    launchesAtLogin = AppController.shared.launchesAtLogin
                }
                SettingsToggle(
                    title: "Ukryj ikonę w Docku",
                    subtitle: "Calcy zniknie z Docka i przełącznika ⌘Tab. Okno otworzysz skrótem ⌃⌥C.",
                    isOn: $hideDockIcon
                )
                .onChange(of: hideDockIcon, initial: true) { _, newValue in
                    AppController.shared.applyDockIconHidden(newValue)
                }
                updates
                shortcuts
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 430, height: 700)
        .background(Color(nsColor: Palette.background))
    }

    private var header: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
            Text("Ustawienia")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.chromeText))
        }
        .frame(height: 38)
    }

    private var fontCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Rozmiar tekstu")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.text))
                    Spacer()
                    Text("\(Int(fontSize)) pt")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.chromeText))
                        .monospacedDigit()
                }
                HStack(spacing: 10) {
                    Text("A").font(.system(size: 11, weight: .semibold))
                    Slider(value: $fontSize, in: SettingsKey.fontSizeRange, step: 1)
                        .tint(Color(nsColor: Palette.result))
                    Text("A").font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color(nsColor: Palette.chromeText))

                // Podgląd dokładnie taki, jak linia w edytorze.
                HStack {
                    Text("cena = 120 zł")
                        .foregroundStyle(Color(nsColor: Palette.text))
                    Spacer()
                    Text("120,00 zł")
                        .foregroundStyle(Color(nsColor: Palette.result))
                }
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: Palette.currentLine)))
            }
        }
    }

    private var updates: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Aktualizacja")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.text))
                    Spacer()
                    Text("wersja \(checker.currentVersion.description)")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.chromeText))
                }

                HStack(spacing: 10) {
                    Text(statusText)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.chromeText))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if case .downloading = checker.state {
                        ProgressView().controlSize(.small)
                    } else if let release = checker.availableRelease {
                        Button("Zaktualizuj do \(release.version.description)") {
                            Task { await checker.install() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: Palette.result))
                        .controlSize(.small)
                    } else {
                        Button("Sprawdź teraz") {
                            Task { await checker.check(manual: true) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Toggle("Sprawdzaj automatycznie (co 6 godzin)", isOn: Binding(
                    get: { checker.automaticChecks },
                    set: { checker.automaticChecks = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.chromeText))
            }
        }
    }

    private var statusText: String {
        switch checker.state {
        case .checking: "Sprawdzam…"
        case .downloading: "Pobieram aktualizację…"
        case .failed(let message): message
        case .available(let release): "Dostępna wersja \(release.version.description)"
        case .upToDate, .idle:
            checker.lastCheck.map { "Masz najnowszą wersję · sprawdzono \($0.formatted(date: .abbreviated, time: .shortened))" }
                ?? "Jeszcze nie sprawdzano"
        }
    }

    private var shortcuts: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Skróty")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.text))
                ForEach([
                    ("⌃⌥C", "Pokaż lub ukryj Calcy"),
                    ("⌃⌥T", "Zawsze na wierzchu"),
                    ("⌘N", "Nowa karta"),
                    ("⌘R", "Zmień nazwę karty"),
                    ("Tab", "Podpowiedzi nazw"),
                ], id: \.0) { shortcut, description in
                    HStack(spacing: 10) {
                        Text(shortcut)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(nsColor: Palette.text))
                            .frame(width: 42, alignment: .leading)
                        Text(description)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Color(nsColor: Palette.chromeText))
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: Palette.control)))
    }
}

private struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.text))
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Color(nsColor: Palette.chromeText))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(nsColor: Palette.result))
            }
        }
    }
}
