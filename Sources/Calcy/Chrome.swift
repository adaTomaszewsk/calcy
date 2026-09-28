import AppKit
import SwiftUI

/// Górny pasek zamiast systemowego tytułu: nazwa bieżącej karty (kliknięcie – zmiana nazwy), przesuwa okno.
struct HeaderBar: View {
    let store: CardStore
    @AppStorage(SettingsKey.alwaysOnTop) private var alwaysOnTop = false
    @State private var draft = ""
    @State private var isHovered = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)

            HStack(spacing: 6) {
                Image(systemName: "equal.square.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: Palette.result))
                if store.isRenaming {
                    nameField
                } else {
                    nameLabel
                }
                if alwaysOnTop {
                    Button { alwaysOnTop = false } label: {
                        Label("Na wierzchu · ⌃⌥T wyłącza", systemImage: "pin.fill")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(nsColor: Palette.result))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(nsColor: Palette.hoverPill)))
                    }
                    .buttonStyle(.plain)
                    .help("Kliknij lub naciśnij ⌃⌥T, aby wyłączyć")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.smooth(duration: 0.2), value: alwaysOnTop)
        }
        .frame(height: 32)
        .padding(.bottom, 6)
    }

    private var nameLabel: some View {
        let card = store.selected
        return HStack(spacing: 5) {
            Text(card.title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: card.customTitle == nil ? Palette.chromeText : Palette.text))
                .lineLimit(1)
            Image(systemName: "pencil")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: Palette.chromeText))
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(nsColor: isHovered ? Palette.control : .clear)))
        .contentShape(Capsule())
        .onHover { isHovered = $0 }
        .onTapGesture { store.isRenaming = true }
        .help("Kliknij, aby zmienić nazwę karty (⌘R)")
        .animation(.smooth(duration: 0.15), value: isHovered)
    }

    private var nameField: some View {
        TextField(store.selected.automaticTitle, text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(nsColor: Palette.text))
            .multilineTextAlignment(.center)
            .frame(width: 220)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(nsColor: Palette.control)))
            .focused($isFieldFocused)
            .onAppear {
                draft = store.selected.customTitle ?? ""
                isFieldFocused = true
            }
            .onSubmit(finish)
            .onExitCommand {
                store.isRenaming = false
                focusEditor()
            }
            .onChange(of: isFieldFocused) { _, focused in
                if !focused, store.isRenaming { finish() }
            }
    }

    private func finish() {
        store.renameSelected(draft)
        store.isRenaming = false
        focusEditor()
    }

    /// Po zmianie nazwy kursor wraca do edytora.
    private func focusEditor() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow, let editor = window.contentView?.firstSubview(of: CalcTextView.self) else { return }
            window.makeFirstResponder(editor)
        }
    }
}

extension NSView {
    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstSubview(of: type) { return match }
        }
        return nil
    }
}

/// Pasek podpowiedzi nad stopką: chipy z nazwami, zaznaczona jest ta wpisana w tekst.
struct CompletionBar: View {
    let candidates: [String]
    let selected: Int

    private static let maxVisible = 8

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(candidates.prefix(Self.maxVisible).enumerated()), id: \.offset) { index, name in
                Text(name)
                    .font(.system(size: 11.5, weight: index == selected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(Color(nsColor: index == selected ? .white : Palette.chromeText))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color(nsColor: index == selected ? Palette.result : Palette.control))
                    )
            }
            if candidates.count > Self.maxVisible {
                Text("+\(candidates.count - Self.maxVisible)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.chromeText))
            }
            Spacer(minLength: 8)
            Text("tab / ← → · ↵ zatwierdź · esc anuluj")
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.chromeText))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color(nsColor: Palette.currentLine))
    }
}

/// Dolny pasek: przełącznik motywu, kropki kart, status kursów (lub potwierdzenie kopiowania).
struct FooterBar: View {
    let cardStore: CardStore
    let rateStore: ExchangeRateStore
    let copiedText: String?

    var body: some View {
        ZStack {
            HStack {
                ThemeSwitch()
                SettingsButton()
                Spacer()
                ZStack(alignment: .trailing) {
                    if let copiedText {
                        Label("Skopiowano \(copiedText)", systemImage: "checkmark")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(nsColor: Palette.copiedResult))
                            .lineLimit(1)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        RateStatus(rateStore: rateStore)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: 220, alignment: .trailing)
            }
            CardDots(store: cardStore)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .animation(.smooth(duration: 0.25), value: copiedText)
    }
}

/// Kropki kart jak w iPhonie + przycisk nowej karty. Nazwa karty pokazuje się po najechaniu.
private struct CardDots: View {
    let store: CardStore
    @State private var hovered: Int?
    @State private var isPlusHovered = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(store.cards.enumerated()), id: \.element.id) { index, card in
                let isSelected = index == store.selectedIndex
                Circle()
                    .fill(Color(nsColor: isSelected ? Palette.text : Palette.chromeText))
                    .opacity(isSelected ? 1 : (hovered == index ? 0.9 : 0.4))
                    .frame(width: isSelected ? 7 : 6, height: isSelected ? 7 : 6)
                    .frame(width: 16, height: 24)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside { hovered = index } else if hovered == index { hovered = nil }
                    }
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.35)) { store.select(index) }
                    }
                    .overlay(alignment: .top) {
                        if hovered == index {
                            Text(card.title)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(nsColor: Palette.text))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: Palette.control))
                                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                                )
                                .offset(y: -26)
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                                .allowsHitTesting(false)
                        }
                    }
            }

            Button {
                withAnimation(.smooth(duration: 0.35)) { store.addCard() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(nsColor: isPlusHovered ? Palette.text : Palette.chromeText))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color(nsColor: isPlusHovered ? Palette.controlHover : .clear)))
            }
            .buttonStyle(.plain)
            .onHover { isPlusHovered = $0 }
            .help("Nowa karta (⌘N)")
            .padding(.leading, 4)

            DeleteCardButton(store: store)
        }
        .animation(.smooth(duration: 0.2), value: hovered)
    }
}

/// Koło zębate – otwiera ustawienia (⌘,).
private struct SettingsButton: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            AppController.shared.openSettingsWindow?()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: isHovered ? Palette.text : Palette.chromeText))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(nsColor: isHovered ? Palette.controlHover : Palette.control)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Ustawienia (⌘,)")
    }
}

/// Mały okrągły przycisk: jasny ↔ ciemny.
private struct ThemeSwitch: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .system
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button {
            theme = colorScheme == .dark ? .light : .dark
        } label: {
            Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: isHovered ? Palette.text : Palette.chromeText))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(nsColor: isHovered ? Palette.controlHover : Palette.control)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(colorScheme == .dark ? "Jasny motyw" : "Ciemny motyw")
        .onChange(of: theme, initial: true) { _, newValue in newValue.apply() }
    }
}

/// Kosz: pierwsze kliknięcie zamienia go w „Usuń kartę?”, drugie usuwa. Bez reakcji wraca po 4 s.
private struct DeleteCardButton: View {
    let store: CardStore
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { store.requestDelete() }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color(nsColor: isHovered ? Palette.danger : Palette.chromeText))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(nsColor: isHovered ? Palette.controlHover : .clear)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Usuń kartę (⇧⌘⌫)")
        .opacity(store.isConfirmingDelete ? 0 : 1)
        // Potwierdzenie wyrasta w miejscu kosza, więc kropki się nie przesuwają.
        .overlay(alignment: .leading) {
            if store.isConfirmingDelete {
                Button {
                    withAnimation(.smooth(duration: 0.35)) { store.deleteSelected() }
                } label: {
                    Label("Usuń kartę?", systemImage: "trash.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(Capsule().fill(Color(nsColor: Palette.danger)))
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.25)) { store.isConfirmingDelete = false }
                }
            }
        }
    }
}

private struct RateStatus: View {
    let rateStore: ExchangeRateStore

    private var dotColor: Color {
        switch rateStore.status {
        case .fresh: Color(nsColor: Palette.copiedResult)
        case .offline: .orange
        case .loading: Color(nsColor: Palette.chromeText)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 5, height: 5)
            Text(rateStore.shortStatusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.chromeText))
                .monospacedDigit()
        }
        .help(rateStore.statusText)
    }
}
