// Rysuje tło okna instalatora DMG (Resources/dmg-background.png i @2x).
// Uruchomienie: swift scripts/make-dmg-background.swift
import AppKit
import CoreGraphics

let width: CGFloat = 640, height: CGFloat = 400

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func draw(in ctx: CGContext) {
    // Gradient jak tło ikony.
    ctx.drawLinearGradient(
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0xE7EDF8), color(0xB9C8E6)] as CFArray, locations: nil)!,
        start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: []
    )

    // Delikatne kropki w tle.
    ctx.setFillColor(color(0xFFFFFF, 0.35))
    for row in 0..<9 {
        for column in 0..<15 {
            let point = CGPoint(x: 26 + CGFloat(column) * 42, y: 22 + CGFloat(row) * 42)
            ctx.fillEllipse(in: CGRect(x: point.x, y: point.y, width: 3, height: 3))
        }
    }

    // Strzałka między ikonami.
    let arrowY = height - 190
    ctx.setStrokeColor(color(0x4F7DF3, 0.55))
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [2, 14])
    ctx.move(to: CGPoint(x: 268, y: arrowY))
    ctx.addLine(to: CGPoint(x: 370, y: arrowY))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.move(to: CGPoint(x: 356, y: arrowY + 13))
    ctx.addLine(to: CGPoint(x: 374, y: arrowY))
    ctx.addLine(to: CGPoint(x: 356, y: arrowY - 13))
    ctx.strokePath()

    // Napisy.
    let title = NSAttributedString(string: "Przeciągnij Calcy do Aplikacji", attributes: [
        .font: NSFont.systemFont(ofSize: 21, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.17, green: 0.19, blue: 0.24, alpha: 1),
    ])
    let subtitle = NSAttributedString(string: "Kalkulator-notatnik na macOS", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.33, green: 0.37, blue: 0.45, alpha: 1),
    ])
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    title.draw(at: CGPoint(x: (width - title.size().width) / 2, y: height - 62))
    subtitle.draw(at: CGPoint(x: (width - subtitle.size().width) / 2, y: height - 88))
}

let scales: [(CGFloat, String)] = [(1, "dmg-background.png"), (2, "dmg-background@2x.png")]
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
for (scale, name) in scales {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    draw(in: ctx)
    let data = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try! data.write(to: root.appendingPathComponent("Resources/\(name)"))
}
print("Gotowe: Resources/dmg-background.png")
