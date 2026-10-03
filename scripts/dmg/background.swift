// 生成 DMG 窗口背景（1x + 2x），用法：swift background.swift <输出目录>
import AppKit

let W: CGFloat = 640, H: CGFloat = 460
let paper = NSColor(srgbRed: 0.965, green: 0.957, blue: 0.937, alpha: 1)
let card = NSColor.white
let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
let muted = NSColor(srgbRed: 0.45, green: 0.45, blue: 0.47, alpha: 1)
let green = NSColor(srgbRed: 0.173, green: 0.451, blue: 0.333, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    // 中文回落苹方
    let desc = base.fontDescriptor.addingAttributes([.cascadeList: [NSFontDescriptor(name: "PingFangSC-Regular", size: size)]])
    return NSFont(descriptor: desc, size: size) ?? base
}

/// 以左上角为原点画文字（Finder 坐标习惯）
func text(_ s: String, _ f: NSFont, _ color: NSColor, x: CGFloat, y: CGFloat, width: CGFloat, align: NSTextAlignment = .center, lineSpacing: CGFloat = 4) {
    let p = NSMutableParagraphStyle(); p.alignment = align; p.lineSpacing = lineSpacing
    let str = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color, .paragraphStyle: p])
    let h = str.boundingRect(with: NSSize(width: width, height: 400), options: .usesLineFragmentOrigin).height
    str.draw(with: NSRect(x: x, y: H - y - h, width: width, height: h), options: .usesLineFragmentOrigin)
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    paper.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

    // 标题
    text("Drag Leaf to the Applications folder", font(19, .semibold), ink, x: 0, y: 34, width: W)

    // 图标之间的箭头（图标中心 y=150，Leaf x=170，Applications x=470）
    let ay = H - 150
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 252, y: ay)); arrow.line(to: NSPoint(x: 380, y: ay))
    arrow.lineWidth = 3; arrow.lineCapStyle = .round
    arrow.setLineDash([2, 9], count: 2, phase: 0)
    green.withAlphaComponent(0.55).setStroke(); arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 376, y: ay + 9)); head.line(to: NSPoint(x: 390, y: ay)); head.line(to: NSPoint(x: 376, y: ay - 9))
    head.lineWidth = 3; head.lineCapStyle = .round; head.lineJoinStyle = .round
    green.setStroke(); head.stroke()

    // 首次打开卡片
    let cardRect = NSRect(x: 28, y: H - 418, width: W - 56, height: 166)  // y 252–418
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.06)
    shadow.shadowBlurRadius = 10; shadow.shadowOffset = NSSize(width: 0, height: -2)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    card.setFill(); NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12).fill()
    NSGraphicsContext.restoreGraphicsState()

    text("Opening Leaf for the first time", font(14, .semibold), ink, x: 52, y: 272, width: 400, align: .left)
    text("Leaf isn’t from the App Store, so macOS blocks it once. Allow it like this:", font(11.5), muted, x: 52, y: 296, width: 540, align: .left)

    let steps = [
        ("Open Leaf", "When the warning\nappears, click Done"),
        ("Open Settings", "Go to System Settings ›\nPrivacy & Security"),
        ("Scroll to the bottom", "Click Open Anyway and\nenter your password"),
    ]
    let colW = (W - 56 - 48) / 3
    for (i, (title, body)) in steps.enumerated() {
        let x = 52 + CGFloat(i) * colW
        let cy = H - 345
        let circle = NSRect(x: x, y: cy - 11, width: 22, height: 22)
        green.setFill(); NSBezierPath(ovalIn: circle).fill()
        text("\(i + 1)", font(12, .bold), .white, x: x, y: 337, width: 22)
        text(title, font(13, .medium), ink, x: x + 30, y: 336, width: colW - 34, align: .left)
        text(body, font(11.5), muted, x: x + 30, y: 358, width: colW - 34, align: .left, lineSpacing: 2)
    }

    text("Requires macOS 15 or later  ·  DRM-protected books, such as Kindle Store purchases, can’t be opened", font(11), muted, x: 0, y: 432, width: W)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
for (scale, name) in [(1.0, "bg.png"), (2.0, "bg@2x.png")] {
    try! render(scale: scale).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}
