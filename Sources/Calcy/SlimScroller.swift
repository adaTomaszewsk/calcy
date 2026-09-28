import AppKit

/// Cienki, zaokrąglony pasek przewijania w kolorach motywu – bez systemowej szyny.
final class SlimScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        12
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let slot = rect(for: .knob)
        let width: CGFloat = 5
        let knob = NSRect(x: slot.maxX - width - 3, y: slot.minY + 3, width: width, height: max(slot.height - 6, width))
        Palette.scrollKnob.setFill()
        NSBezierPath(roundedRect: knob, xRadius: width / 2, yRadius: width / 2).fill()
    }
}
