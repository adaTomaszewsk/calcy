import AppKit
import SwiftUI

/// Edytor jednej karty. Przy zmianie karty SwiftUI tworzy go na nowo (`.id(card.id)`).
struct CalcEditor: NSViewRepresentable {
    let initialText: String
    let rateStore: ExchangeRateStore
    let onTextChange: (String) -> Void
    let onCopy: (String) -> Void
    let onCompletions: ((([String], Int)?) -> Void)
    let fontSize: Double
    /// Przesunięcie dwoma palcami w bok: 1 – następna karta, -1 – poprzednia.
    let onSwipe: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = SwipeScrollView()
        scrollView.onSwipe = onSwipe
        scrollView.verticalScroller = SlimScroller()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Palette.background

        let textView = CalcTextView(usingTextLayoutManager: false)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.configure()
        textView.fontSize = fontSize
        textView.string = initialText
        textView.delegate = context.coordinator
        textView.onCopy = onCopy
        textView.onCompletions = onCompletions
        textView.rates = rateStore.rates
        rateStore.onChange = { [weak textView] rates in textView?.rates = rates }

        scrollView.documentView = textView
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        (nsView.documentView as? CalcTextView)?.fontSize = fontSize
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let onTextChange: (String) -> Void

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CalcTextView else { return }
            textView.endCompletion()
            onTextChange(textView.string)
            textView.recalculate()
        }
    }
}

/// Rozpoznaje poziome przesunięcie dwoma palcami na gładziku (jak zmiana strony w iPhonie).
final class SwipeScrollView: NSScrollView {
    var onSwipe: ((Int) -> Void)?

    private var accumulated: CGFloat = 0
    private var isHorizontal: Bool?
    private static let threshold: CGFloat = 70

    /// Edytor zawsze wypełnia całą widoczną wysokość – krótka karta nie ucina wyników
    /// ostatniej linii, a kliknięcie pod tekstem trafia w edytor.
    override func tile() {
        super.tile()
        guard let textView = documentView as? NSTextView else { return }
        let height = contentSize.height
        if textView.minSize.height != height {
            textView.minSize = NSSize(width: 0, height: height)
        }
        if textView.frame.height < height {
            textView.setFrameSize(NSSize(width: textView.frame.width, height: height))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        // Zwykłe kółko myszy i bezwładność po geście – standardowo.
        guard event.hasPreciseScrollingDeltas, event.momentumPhase == [] else {
            if isHorizontal != true { super.scrollWheel(with: event) }
            return
        }

        if event.phase == .began {
            accumulated = 0
            isHorizontal = nil
        }
        if isHorizontal == nil, abs(event.scrollingDeltaX) + abs(event.scrollingDeltaY) > 2 {
            isHorizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.5
        }
        guard isHorizontal == true else {
            super.scrollWheel(with: event)
            return
        }

        accumulated += event.scrollingDeltaX
        if event.phase == .ended || event.phase == .cancelled {
            if abs(accumulated) > Self.threshold {
                // Palce w lewo (ujemna delta) → następna karta.
                onSwipe?(accumulated < 0 ? 1 : -1)
            }
            accumulated = 0
            isHorizontal = nil
        }
    }
}
