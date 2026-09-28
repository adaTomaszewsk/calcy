import AppKit
import CalcEngine

/// Edytor tekstu, który po prawej stronie rysuje wynik każdej linii.
final class CalcTextView: NSTextView {
    private var calculator = Calculator()
    private var clockTask: Task<Void, Never>?

    var rates: ExchangeRates? {
        didSet {
            calculator.rates = rates
            recalculate()
        }
    }
    private let formatter: ValueFormatter = {
        var formatter = ValueFormatter()
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    private var results: [LineResult] = []
    private var lineLengths: [Int] = []
    private var copiedLine: Int?
    private var hoveredLine: Int?

    /// Wywoływane po skopiowaniu wyniku (stopka pokazuje potwierdzenie).
    var onCopy: ((String) -> Void)?
    /// Lista podpowiedzi i zaznaczona pozycja; `nil` chowa pasek.
    var onCompletions: ((([String], Int)?) -> Void)?

    /// Rozmiar tekstu z ustawień (⌘,).
    var fontSize: CGFloat = 15 {
        didSet {
            guard oldValue != fontSize else { return }
            font = bodyFont
            typingAttributes = baseAttributes
            recalculate()
        }
    }

    private var bodyFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    private var headerFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .bold) }
    private var resultFont: NSFont { .monospacedSystemFont(ofSize: fontSize, weight: .medium) }
    private var resultLineHeight: CGFloat { ceil(NSLayoutManager().defaultLineHeight(for: resultFont)) }
    private let gutter: CGFloat = 32
    private static let lineSpacing: CGFloat = 8

    private var resultColumnWidth: CGFloat {
        min(max(bounds.width * 0.35, 160), 380)
    }

    private var resultColumnMinX: CGFloat {
        bounds.width - resultColumnWidth
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Self.lineSpacing
        return style
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: Palette.text, .paragraphStyle: paragraphStyle]
    }

    func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFindBar = true
        font = bodyFont
        backgroundColor = Palette.background
        drawsBackground = true
        insertionPointColor = Palette.caret
        textContainerInset = NSSize(width: 28, height: 12)
        selectedTextAttributes = [.backgroundColor: Palette.selection]
        defaultParagraphStyle = paragraphStyle
        typingAttributes = baseAttributes
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
    }

    // MARK: - Liczenie

    /// Przelicza co 30 s, żeby `teraz` i `dziś` nie stały w miejscu.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clockTask?.cancel()
        guard window != nil else { return }
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.recalculate()
            }
        }
    }

    func recalculate() {
        let lines = string.components(separatedBy: "\n")
        lineLengths = lines.map { ($0 as NSString).length }
        results = calculator.evaluate(lines: lines)
        highlight(lines)
        needsDisplay = true
    }

    private func highlight(_ lines: [String]) {
        guard let storage = textStorage else { return }
        var variables = Set<String>()
        for result in results {
            if case .assignment(let name) = result.kind { variables.insert(name) }
        }

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: NSRange(location: 0, length: storage.length))
        var location = 0
        for line in lines {
            for highlight in Highlighter.highlight(line, variables: variables) {
                let range = NSRange(location: location + highlight.range.location, length: highlight.range.length)
                storage.addAttributes(Self.attributes(for: highlight.kind, headerFont: headerFont), range: range)
            }
            location += (line as NSString).length + 1
        }
        storage.endEditing()
    }

    private static func attributes(for kind: HighlightKind, headerFont: NSFont) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .number: [.foregroundColor: Palette.number]
        case .variable: [.foregroundColor: Palette.variable]
        case .function, .keyword: [.foregroundColor: Palette.keyword]
        case .unit: [.foregroundColor: Palette.unit]
        case .symbol, .label: [.foregroundColor: Palette.secondary]
        case .comment: [.foregroundColor: Palette.comment]
        case .header: [.font: headerFont]
        }
    }

    // MARK: - Układ

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard let container = textContainer else { return }
        let width = max(120, newSize.width - resultColumnWidth - textContainerInset.width - gutter)
        if container.containerSize.width != width {
            container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
    }

    /// Prostokąty pierwszego wiersza każdej linii dokumentu (w układzie widoku).
    private func lineRects() -> [NSRect] {
        guard let layoutManager else { return [] }
        let length = (string as NSString).length
        let origin = textContainerOrigin
        var rects: [NSRect] = []
        var location = 0
        for lineLength in lineLengths {
            var rect: NSRect
            if location < length {
                let glyph = layoutManager.glyphIndexForCharacter(at: location)
                rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                rect = layoutManager.extraLineFragmentRect
            }
            rect.origin.y += origin.y
            rects.append(rect)
            location += lineLength + 1
        }
        return rects
    }

    // MARK: - Rysowanie wyników

    // Rysujemy w tle, bo tekst NSTextView jest renderowany na osobnych warstwach nad nim.
    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        let rects = lineRects()

        // Pusta karta: tylko podpowiedź, bez podświetlenia linii (inaczej by ją przykrywało).
        if string.isEmpty {
            let placeholder = NSAttributedString(
                string: "Zacznij liczyć…   np. cena = 120 zł",
                attributes: [.font: bodyFont, .foregroundColor: Palette.comment]
            )
            let x = textContainerOrigin.x + (textContainer?.lineFragmentPadding ?? 5) + 8
            placeholder.draw(at: NSPoint(x: x, y: textContainerOrigin.y))
            return
        }

        // Podświetlenie bieżącej linii (razem z jej wynikiem).
        if selectedRange().length == 0, let current = currentParagraphRect() {
            Palette.currentLine.setFill()
            let card = current.insetBy(dx: textContainerInset.width - 12, dy: 0)
            NSBezierPath(roundedRect: card, xRadius: 8, yRadius: 8).fill()
        }

        for (index, rect) in rects.enumerated() where rect.maxY >= dirtyRect.minY && rect.minY - 8 <= dirtyRect.maxY {
            guard let text = displayText(forLine: index) else { continue }
            let attributed = NSAttributedString(string: text, attributes: resultAttributes(forLine: index))
            let right = bounds.width - textContainerInset.width
            let width = min(attributed.size().width, right - resultColumnMinX)
            // Wysokość z czcionki, nie z wiersza – ostatni wiersz nie ma odstępu pod spodem.
            let textRect = NSRect(x: right - width, y: rect.minY, width: width, height: resultLineHeight)

            if index == hoveredLine || index == copiedLine {
                (index == copiedLine ? Palette.copiedPill : Palette.hoverPill).setFill()
                let pill = textRect.insetBy(dx: -8, dy: -3)
                NSBezierPath(roundedRect: pill, xRadius: 7, yRadius: 7).fill()
            }
            // Za długi wynik jest ucinany wielokropkiem – pełną wartość daje kliknięcie (kopiowanie).
            attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    /// Cała linia dokumentu z kursorem (także gdy jest zawinięta na kilka wierszy), na pełną szerokość.
    private func currentParagraphRect() -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let text = string as NSString
        let location = selectedRange().location
        var rect: NSRect
        if location >= text.length, text.length == 0 || text.character(at: text.length - 1) == 10 {
            rect = layoutManager.extraLineFragmentRect
        } else {
            let paragraph = text.paragraphRange(for: NSRange(location: min(location, text.length - 1), length: 0))
            let glyphs = layoutManager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        }
        guard rect.height > 0 else { return nil }
        rect.origin.y += textContainerOrigin.y - Self.lineSpacing / 2
        return NSRect(x: 0, y: rect.minY, width: bounds.width, height: rect.height)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        endCompletion()
        needsDisplay = true
    }

    // MARK: - Najechanie na wynik

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self && area.userInfo?["results"] != nil {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["results": true]
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let line = resultLine(at: convert(event.locationInWindow, from: nil))
        if line != hoveredLine {
            hoveredLine = line
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if hoveredLine != nil {
            hoveredLine = nil
            needsDisplay = true
        }
    }

    /// Linia, której wynik jest pod kursorem myszy.
    private func resultLine(at point: NSPoint) -> Int? {
        guard point.x >= resultColumnMinX,
              let index = lineRects().firstIndex(where: { point.y >= $0.minY - 4 && point.y < $0.maxY - 4 }),
              displayText(forLine: index) != nil
        else { return nil }
        return index
    }

    private func displayText(forLine index: Int) -> String? {
        guard results.indices.contains(index), let value = results[index].value else { return nil }
        return formatter.format(value)
    }

    private func resultAttributes(forLine index: Int) -> [NSAttributedString.Key: Any] {
        let color: NSColor
        if copiedLine == index {
            color = Palette.copiedResult
        } else if case .assignment = results[index].kind {
            color = Palette.assignedResult
        } else {
            color = Palette.result
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return [.font: resultFont, .foregroundColor: color, .paragraphStyle: style]
    }

    // MARK: - Kopiowanie wyniku kliknięciem

    /// NSTextView przepuszcza kliknięcia spoza obszaru tekstu – a kolumna wyników leży właśnie poza nim.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) { return hit }
        return frame.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let index = resultLine(at: convert(event.locationInWindow, from: nil)),
              let value = results[index].value
        else {
            super.mouseDown(with: event)
            return
        }

        let text = formatter.format(value, grouping: false)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        onCopy?(text)
        copiedLine = index
        needsDisplay = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, self.copiedLine == index else { return }
            self.copiedLine = nil
            self.needsDisplay = true
        }
    }

    // MARK: - Podpowiedzi (Tab)

    /// Trwające uzupełnianie: co zastępujemy, czym i na której podpowiedzi stoimy.
    private struct Completion {
        var range: NSRange
        let prefix: String
        let candidates: [String]
        var index: Int
    }

    private var completion: Completion? {
        didSet { onCompletions?(completion.map { ($0.candidates, $0.index) }) }
    }
    /// Własne zmiany tekstu nie mogą przerywać uzupełniania.
    private var isApplyingCompletion = false

    /// Tab: jedno dopasowanie – uzupełnia od razu, kilka – pokazuje pasek podpowiedzi i przechodzi po nich.
    override func insertTab(_ sender: Any?) {
        if completion != nil {
            step(by: 1)
            return
        }
        guard let range = identifierRangeBeforeCursor() else {
            super.insertTab(sender)
            return
        }
        let prefix = (string as NSString).substring(with: range)
        let candidates = completionCandidates(for: prefix)
        switch candidates.count {
        case 0:
            NSSound.beep()
        case 1:
            apply(candidates[0], in: range)
        default:
            completion = Completion(range: range, prefix: prefix, candidates: candidates, index: 0)
            applyCurrentCandidate()
        }
    }

    override func insertBacktab(_ sender: Any?) {
        guard completion != nil else {
            super.insertBacktab(sender)
            return
        }
        step(by: -1)
    }

    override func moveRight(_ sender: Any?) {
        completion == nil ? super.moveRight(sender) : step(by: 1)
    }

    override func moveLeft(_ sender: Any?) {
        completion == nil ? super.moveLeft(sender) : step(by: -1)
    }

    /// Enter zatwierdza podpowiedź (i nie przechodzi do nowej linii).
    override func insertNewline(_ sender: Any?) {
        guard completion != nil else {
            super.insertNewline(sender)
            return
        }
        completion = nil
    }

    /// Esc wraca do tego, co było wpisane.
    override func cancelOperation(_ sender: Any?) {
        guard let current = completion else {
            super.cancelOperation(sender)
            return
        }
        apply(current.prefix, in: current.range)
        completion = nil
    }

    private func step(by offset: Int) {
        guard var current = completion else { return }
        current.index = (current.index + offset + current.candidates.count) % current.candidates.count
        completion = current
        applyCurrentCandidate()
    }

    private func applyCurrentCandidate() {
        guard var current = completion else { return }
        let text = current.candidates[current.index]
        apply(text, in: current.range)
        current.range = NSRange(location: current.range.location, length: (text as NSString).length)
        completion = current
    }

    private func apply(_ text: String, in range: NSRange) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        isApplyingCompletion = true
        replaceCharacters(in: range, with: text)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        isApplyingCompletion = false
        recalculate()
    }

    /// Klik, przesunięcie kursora albo dalsze pisanie kończy uzupełnianie.
    func endCompletion() {
        guard !isApplyingCompletion else { return }
        completion = nil
    }

    /// Nazwa (litery, cyfry, `_`) kończąca się na kursorze. `nil`, gdy jej nie ma albo to liczba.
    private func identifierRangeBeforeCursor() -> NSRange? {
        let selection = selectedRange()
        guard selection.length == 0 else { return nil }
        let text = string as NSString
        let identifierCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        var start = selection.location
        while start > 0, let scalar = UnicodeScalar(text.character(at: start - 1)), identifierCharacters.contains(scalar) {
            start -= 1
        }
        guard start < selection.location,
              let first = UnicodeScalar(text.character(at: start)),
              !CharacterSet.decimalDigits.contains(first)
        else { return nil }
        return NSRange(location: start, length: selection.location - start)
    }

    /// Zmienne z dokumentu (najpierw te zdefiniowane najbliżej nad kursorem), potem funkcje i słowa kluczowe.
    private func completionCandidates(for prefix: String) -> [String] {
        let cursorLine = lineIndex(at: selectedRange().location)
        var variables: [(name: String, distance: Int)] = []
        for (index, result) in results.enumerated() {
            guard case .assignment(let name) = result.kind else { continue }
            // Zmienne spod kursora są dalej na liście niż wszystkie te znad niego.
            let distance = index < cursorLine ? cursorLine - index : results.count + index
            variables.append((name, distance))
        }

        var seen = Set<String>()
        let ordered = variables.sorted { $0.distance < $1.distance }.map(\.name) + Calculator.builtinWords
        return ordered.filter { word in
            word.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
                && seen.insert(word).inserted
        }
    }

    private func lineIndex(at location: Int) -> Int {
        var remaining = location
        for (index, length) in lineLengths.enumerated() {
            if remaining <= length { return index }
            remaining -= length + 1
        }
        return max(lineLengths.count - 1, 0)
    }
}
