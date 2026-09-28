// Rysuje ikonę Calcy i składa Resources/AppIcon.icns.
// Uruchomienie: swift scripts/make-icon.swift
import AppKit
import CoreGraphics

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

func roundedBar(_ rect: CGRect) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
}

/// Ragdoll w okularach: biały, długowłosy, z szarą maską. Na jednym szkle „+”, na drugim „−”.
/// Płótno 1024 × 1024, oś Y w górę (siatka ikon macOS: korpus 824 pt z marginesem na cień).
/// Sama ikona: jasnoniebieskie tło w kształcie ikony macOS + kot.
func drawIcon(in ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(color(0xC3D0EA))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.drawLinearGradient(gradient([color(0xDCE5F5), color(0xA9BBDF)]),
                           start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
    drawCat(in: ctx)
    ctx.restoreGState()

    // Cienka krawędź korpusu.
    ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    ctx.setStrokeColor(color(0x000000, 0.06))
    ctx.setLineWidth(3)
    ctx.strokePath()
}

/// Sam kot, bez tła – do osobnego PNG z przezroczystością.
func drawCat(in ctx: CGContext) {
    let accent = color(0x4F7DF3)
    let fur = gradient([color(0xFFFFFF), color(0xEEEAE4)])

    // Uszy: szare, z różowym środkiem i białymi kosmykami.
    for side: CGFloat in [-1, 1] {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + side * x, y: y) }
        ctx.addLines(between: [p(-248, 570), p(-196, 820), p(-66, 672)])
        ctx.closePath()
        ctx.setFillColor(color(0x7E838E))
        ctx.setStrokeColor(color(0x7E838E))
        ctx.setLineWidth(52)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)

        ctx.addLines(between: [p(-212, 612), p(-186, 752), p(-110, 668)])
        ctx.closePath()
        ctx.setFillColor(color(0xEDB2BE))
        ctx.setStrokeColor(color(0xEDB2BE))
        ctx.setLineWidth(18)
        ctx.drawPath(using: .fillStroke)

        ctx.setStrokeColor(color(0xFFFFFF, 0.9))
        ctx.setLineWidth(7)
        ctx.setLineCap(.round)
        for (from, to) in [(p(-186, 612), p(-178, 690)), (p(-162, 614), p(-146, 680)), (p(-138, 620), p(-118, 668))] {
            ctx.move(to: from)
            ctx.addLine(to: to)
        }
        ctx.strokePath()
    }

    // Głowa z kryzą długiej sierści wokół policzków i brody.
    let center = CGPoint(x: 512, y: 452)
    let a: CGFloat = 292, b: CGFloat = 226
    let headRect = CGRect(x: center.x - a, y: center.y - b, width: a * 2, height: b * 2)
    func onEllipse(_ angle: CGFloat, _ extra: CGFloat) -> CGPoint {
        CGPoint(x: center.x + (a + extra) * cos(angle), y: center.y + (b + extra) * sin(angle))
    }
    let ruff = CGMutablePath()
    let tufts = 11
    let startAngle = CGFloat.pi * 0.95, endAngle = CGFloat.pi * 2.05
    ruff.move(to: center)
    ruff.addLine(to: onEllipse(startAngle, -16))
    for i in 0..<tufts {
        let t0 = startAngle + (endAngle - startAngle) * CGFloat(i) / CGFloat(tufts)
        let t1 = startAngle + (endAngle - startAngle) * CGFloat(i + 1) / CGFloat(tufts)
        let dt = t1 - t0
        // Miękkie, lekko podwinięte kosmyki – najdłuższe na policzkach i pod brodą.
        let length: CGFloat = 34 + 30 * abs(sin((t0 + t1) / 2)) + (i % 2 == 0 ? 6 : -4)
        ruff.addCurve(
            to: onEllipse(t1, -16),
            control1: onEllipse(t0 + dt * 0.2, length * 1.25),
            control2: onEllipse(t0 + dt * 0.95, length * 1.1)
        )
    }
    ruff.closeSubpath()

    for path in [CGPath(ellipseIn: headRect, transform: nil), ruff as CGPath] {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(fur, start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 150), options: [])
        ctx.restoreGState()
    }

    // Szara maska ragdolla (miękkie brzegi), a na niej biały klin na czole i biały pyszczek.
    ctx.saveGState()
    ctx.addEllipse(in: headRect)
    ctx.clip()
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 486)
    ctx.scaleBy(x: 1, y: 0.62)
    ctx.drawRadialGradient(gradient([color(0x8C919C), color(0x8C919C), color(0x8C919C, 0)]),
                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 330, options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    let blaze = CGMutablePath()
    blaze.move(to: CGPoint(x: 512, y: 640))
    blaze.addQuadCurve(to: CGPoint(x: 424, y: 300), control: CGPoint(x: 488, y: 420))
    blaze.addLine(to: CGPoint(x: 600, y: 300))
    blaze.addQuadCurve(to: CGPoint(x: 512, y: 640), control: CGPoint(x: 536, y: 420))
    ctx.addPath(blaze)
    ctx.addEllipse(in: CGRect(x: 396, y: 226, width: 232, height: 150))
    ctx.setFillColor(color(0xFBFAF8))
    ctx.fillPath()

    // Okulary w ciemnej oprawce.
    let left = CGPoint(x: 396, y: 478), right = CGPoint(x: 628, y: 478)
    let radius: CGFloat = 94
    let frame = color(0x2B2D33)

    ctx.setStrokeColor(frame)
    ctx.setLineCap(.round)
    ctx.setLineWidth(18)
    ctx.move(to: CGPoint(x: left.x - radius + 4, y: left.y + 12))
    ctx.addLine(to: CGPoint(x: 226, y: left.y + 40))
    ctx.move(to: CGPoint(x: right.x + radius - 4, y: right.y + 12))
    ctx.addLine(to: CGPoint(x: 798, y: right.y + 40))
    ctx.strokePath()

    ctx.setLineWidth(20)
    ctx.move(to: CGPoint(x: left.x + radius - 6, y: left.y + 16))
    ctx.addQuadCurve(to: CGPoint(x: right.x - radius + 6, y: right.y + 16), control: CGPoint(x: 512, y: left.y + 54))
    ctx.strokePath()

    for lensCenter in [left, right] {
        let lens = CGRect(x: lensCenter.x - radius, y: lensCenter.y - radius, width: radius * 2, height: radius * 2)
        ctx.addEllipse(in: lens)
        ctx.setFillColor(color(0xF7F9FF))
        ctx.fillPath()
        ctx.addEllipse(in: lens.insetBy(dx: 10, dy: 10))
        ctx.setStrokeColor(frame)
        ctx.setLineWidth(20)
        ctx.strokePath()
        ctx.setStrokeColor(color(0xD5E0FA))
        ctx.setLineWidth(10)
        ctx.addArc(center: lensCenter, radius: radius - 36, startAngle: .pi * 0.58, endAngle: .pi * 0.82, clockwise: false)
        ctx.strokePath()
    }

    // „+” na lewym szkle, „−” na prawym.
    let barLength: CGFloat = 92, barThickness: CGFloat = 23
    ctx.setFillColor(accent)
    ctx.addPath(roundedBar(CGRect(x: left.x - barLength / 2, y: left.y - barThickness / 2, width: barLength, height: barThickness)))
    ctx.addPath(roundedBar(CGRect(x: left.x - barThickness / 2, y: left.y - barLength / 2, width: barThickness, height: barLength)))
    ctx.addPath(roundedBar(CGRect(x: right.x - barLength / 2, y: right.y - barThickness / 2, width: barLength, height: barThickness)))
    ctx.fillPath()

    // Nosek, pyszczek, wąsy.
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: 488, y: 336))
    nose.addLine(to: CGPoint(x: 536, y: 336))
    nose.addLine(to: CGPoint(x: 512, y: 310))
    nose.closeSubpath()
    ctx.addPath(nose)
    ctx.setFillColor(color(0xE39AAA))
    ctx.setStrokeColor(color(0xE39AAA))
    ctx.setLineWidth(15)
    ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)

    ctx.setStrokeColor(color(0x9A9FA9))
    ctx.setLineWidth(8)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 512, y: 304))
    ctx.addQuadCurve(to: CGPoint(x: 470, y: 274), control: CGPoint(x: 500, y: 272))
    ctx.move(to: CGPoint(x: 512, y: 304))
    ctx.addQuadCurve(to: CGPoint(x: 554, y: 274), control: CGPoint(x: 524, y: 272))
    ctx.strokePath()

    ctx.setStrokeColor(color(0xA3A8B2, 0.75))
    ctx.setLineWidth(6)
    for (from, to) in [
        (CGPoint(x: 404, y: 322), CGPoint(x: 246, y: 344)), (CGPoint(x: 404, y: 300), CGPoint(x: 252, y: 286)),
        (CGPoint(x: 620, y: 322), CGPoint(x: 778, y: 344)), (CGPoint(x: 620, y: 300), CGPoint(x: 772, y: 286)),
    ] {
        ctx.move(to: from)
        ctx.addLine(to: to)
    }
    ctx.strokePath()
}

func png(size: Int, draw: (CGContext) -> Void = drawIcon) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try! png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! png(size: 1024).write(to: root.appendingPathComponent("Resources/AppIcon-preview.png"))
// Sam kot na przezroczystym tle – do wykorzystania poza aplikacją.
try! png(size: 1024, draw: drawCat).write(to: root.appendingPathComponent("Resources/Calcy-kot.png"))

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Gotowe: Resources/AppIcon.icns" : "iconutil nie powiódł się")
