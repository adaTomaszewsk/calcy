import AppKit
import SwiftUI

@main
struct CalcyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var cardStore = CardStore()
    @State private var rateStore = ExchangeRateStore()
    @AppStorage(SettingsKey.alwaysOnTop) private var alwaysOnTop = false

    var body: some Scene {
        Window("Calcy", id: "main") {
            MainView(cardStore: cardStore, rateStore: rateStore)
        }
        .defaultSize(width: 780, height: 540)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                LaunchAtLoginToggle()
                Button("Pokaż/ukryj Calcy: \(AppController.hotKeyDescription) (skrót globalny)") {}
                    .disabled(true)
            }
            ThemeCommands()
            CardCommands(store: cardStore)
            CommandGroup(replacing: .appSettings) {
                Button("Ustawienia…") { AppController.shared.openSettingsWindow?() }
                    .keyboardShortcut(",")
            }
            CommandGroup(after: .toolbar) {
                Toggle("Zawsze na wierzchu", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.control, .option])
            }
        }

        // Ustawienia jako zwykłe okno – systemowa scena Settings ma wygląd systemowy.
        Window("Ustawienia", id: "settings") {
            SettingsView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct MainView: View {
    let cardStore: CardStore
    let rateStore: ExchangeRateStore
    @Environment(\.openWindow) private var openWindow
    @State private var copiedText: String?
    @State private var completions: (candidates: [String], selected: Int)?
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsKey.defaultFontSize
    @AppStorage(SettingsKey.alwaysOnTop) private var alwaysOnTop = false
    @AppStorage(SettingsKey.hideDockIcon) private var hideDockIcon = false
    @State private var updateChecker = UpdateChecker.shared
    @State private var copyGeneration = 0

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(store: cardStore)
            ZStack {
                let card = cardStore.selected
                CalcEditor(
                    initialText: card.text,
                    rateStore: rateStore,
                    onTextChange: { cardStore.updateText(ofCard: card.number, to: $0) },
                    onCopy: showCopied,
                    onCompletions: { update in
                        withAnimation(.smooth(duration: 0.18)) {
                            completions = update.map { (candidates: $0.0, selected: $0.1) }
                        }
                    },
                    fontSize: fontSize,
                    onSwipe: { step in
                        withAnimation(.smooth(duration: 0.35)) {
                            step > 0 ? cardStore.selectNext() : cardStore.selectPrevious()
                        }
                    }
                )
                .id(card.id)
                .transition(.push(from: cardStore.direction > 0 ? .trailing : .leading))
            }
            .clipped()
            if let release = updateChecker.availableRelease {
                UpdateBar(checker: updateChecker, release: release)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let completions {
                CompletionBar(candidates: completions.candidates, selected: completions.selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            FooterBar(cardStore: cardStore, rateStore: rateStore, copiedText: copiedText)
        }
        .background(Color(nsColor: Palette.background))
        .ignoresSafeArea()
        // Widoczna ramka, gdy okno jest przypięte nad innymi.
        .overlay {
            if alwaysOnTop {
                // Promień jak w oknie macOS – inaczej ramka ginie w rogach.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(nsColor: Palette.result).opacity(0.75), lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: alwaysOnTop, initial: true) { _, isOn in
            AppController.shared.applyAlwaysOnTop(isOn)
        }
        .onChange(of: hideDockIcon, initial: true) { _, isHidden in
            AppController.shared.applyDockIconHidden(isHidden)
        }
        .frame(minWidth: 480, minHeight: 300)
        .navigationTitle(cardStore.selected.title)
        .task { await rateStore.keepUpdated() }
        .task { await updateChecker.runPeriodically() }
        .animation(.smooth(duration: 0.25), value: updateChecker.availableRelease)
        .onAppear {
            AppController.shared.openMainWindow = { openWindow(id: "main") }
            AppController.shared.openSettingsWindow = { openWindow(id: "settings") }
        }
    }

    private func showCopied(_ text: String) {
        copyGeneration += 1
        let generation = copyGeneration
        copiedText = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if generation == copyGeneration { copiedText = nil }
        }
    }
}

/// Menu Plik: karty.
private struct CardCommands: Commands {
    let store: CardStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nowa karta") { animate { store.addCard() } }
                .keyboardShortcut("n")
            Button("Następna karta") { animate { store.selectNext() } }
                .keyboardShortcut(.tab, modifiers: .control)
            Button("Poprzednia karta") { animate { store.selectPrevious() } }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
            Button("Zmień nazwę karty") { store.isRenaming = true }
                .keyboardShortcut("r")
            Divider()
            ForEach(1...9, id: \.self) { number in
                Button("Karta \(number)") { animate { store.select(number - 1) } }
                    .keyboardShortcut(KeyEquivalent(Character(String(number))))
                    .disabled(number > store.cards.count)
            }
            Divider()
            Button("Usuń kartę") { animate { store.requestDelete() } }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }
    }

    private func animate(_ action: () -> Void) {
        withAnimation(.smooth(duration: 0.35), action)
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isOn = AppController.shared.launchesAtLogin

    var body: some View {
        Toggle("Uruchamiaj przy logowaniu", isOn: $isOn)
            .onChange(of: isOn) { _, newValue in
                AppController.shared.launchesAtLogin = newValue
                isOn = AppController.shared.launchesAtLogin
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Potrzebne przy uruchamianiu przez `swift run` (bez paczki .app).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        Theme.current.apply()
        AppController.shared.registerHotKey()
    }

    /// Zamknięcie okna nie wyłącza aplikacji – skrót globalny musi dalej działać. Wyjście: ⌘Q.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            AppController.shared.showWindow()
        }
        return true
    }
}
