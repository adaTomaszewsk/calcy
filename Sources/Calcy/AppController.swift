import AppKit
import Carbon.HIToolbox
import ServiceManagement
import Updater

/// Globalny skrót klawiszowy i zachowanie aplikacji w tle.
@MainActor
final class AppController {
    static let shared = AppController()

    /// Skrót: ⌃⌥C.
    static let hotKeyCode = UInt32(kVK_ANSI_C)
    static let hotKeyModifiers = UInt32(controlKey | optionKey)
    static let hotKeyDescription = "⌃⌥C"

    /// Otwiera okno SwiftUI, gdy zostało zamknięte. Ustawiane przez widok.
    var openMainWindow: (() -> Void)?
    /// Otwiera okno ustawień. Ustawiane przez widok.
    var openSettingsWindow: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var availableRelease: Release?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// Rejestruje skrót przez Carbon – nie wymaga uprawnień dostępności.
    func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { AppController.shared.toggleWindow() }
            return noErr
        }, 1, &eventType, nil, &eventHandler)

        let id = EventHotKeyID(signature: OSType(0x4341_4C43), id: 1) // "CALC"
        let status = RegisterEventHotKey(Self.hotKeyCode, Self.hotKeyModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Calcy: nie udało się zarejestrować skrótu \(Self.hotKeyDescription) (błąd \(status)) – może używa go inna aplikacja")
        }
    }

    /// Pokazuje Calcy na wierzchu, a jeśli już jest na wierzchu – chowa.
    func toggleWindow() {
        let window = NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
        if NSApp.isActive, let window, window.isKeyWindow {
            NSApp.hide(nil)
            return
        }
        showWindow()
    }

    func showWindow() {
        NSApp.unhide(nil)
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    // MARK: - Okno na wierzchu

    /// Okno główne zostaje nad oknami innych aplikacji.
    func applyAlwaysOnTop(_ isOn: Bool) {
        for window in NSApp.windows where window.canBecomeMain {
            window.level = isOn ? .floating : .normal
        }
    }

    // MARK: - Ikona w Docku

    /// Bez ikony w Docku aplikacja działa w tle – wtedy pokazujemy ją w pasku menu,
    /// żeby było widać, że działa, i dało się ją stamtąd obsłużyć.
    func applyDockIconHidden(_ isHidden: Bool) {
        isHidden ? showStatusItem() : hideStatusItem()

        let policy: NSApplication.ActivationPolicy = isHidden ? .accessory : .regular
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        NSApp.activate()
    }

    /// Kropka przy ikonie w pasku menu i pozycja „Zaktualizuj”, gdy jest nowa wersja.
    func updateStatusItem(release: Release?) {
        availableRelease = release
        guard statusItem != nil else { return }
        hideStatusItem()
        showStatusItem()
    }

    private func showStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let icon = NSApp.applicationIconImage.copy() as? NSImage ?? NSImage()
            icon.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.toolTip = "Calcy – \(Self.hotKeyDescription) pokazuje okno"
        }

        if availableRelease != nil, let button = item.button {
            button.title = " ●"
            button.attributedTitle = NSAttributedString(string: " ●", attributes: [
                .foregroundColor: NSColor.controlAccentColor,
                .font: NSFont.systemFont(ofSize: 9),
            ])
            button.toolTip = "Calcy – dostępna aktualizacja"
        }

        let menu = NSMenu()
        if let release = availableRelease {
            menu.addItem(withTitle: "Zaktualizuj do \(release.version)", action: #selector(installUpdateFromStatusItem), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Pokaż Calcy  \(Self.hotKeyDescription)", action: #selector(showFromStatusItem), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Ustawienia…", action: #selector(openSettingsFromStatusItem), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Zakończ Calcy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    private func hideStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func installUpdateFromStatusItem() {
        Task { await UpdateChecker.shared.install() }
    }

    @objc private func showFromStatusItem() {
        showWindow()
    }

    @objc private func openSettingsFromStatusItem() {
        showWindow()
        openSettingsWindow?()
    }

    // MARK: - Uruchamianie przy logowaniu

    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Calcy: nie udało się zmienić uruchamiania przy logowaniu: \(error)")
            }
        }
    }
}
