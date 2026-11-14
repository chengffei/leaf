// 文档图标：白页加折角，左下压一枚 Leaf 绿徽章（Word 那种做法），右下写格式名。
// 用法：cd scripts/docicons && swiftc -O gen.swift -o /tmp/gen && /tmp/gen PDF EPUB KINDLE
//      然后 iconutil -c icns PDF.iconset -o ../../Leaf/PDFDocument.icns（EPUB、KINDLE 同理，KINDLE 存成 KindleDocument.icns）
// 16 和 32 像素只画页面和徽章：线条与文字在这个尺寸只会糊成一片
import AppKit

// 坐标系：0–1，原点左下
func render(px: Int, label: String) -> NSBitmapImageRep {
  let s = CGFloat(px)
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  let ctx = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.current = ctx
  let g = ctx.cgContext
  g.scaleBy(x: s, y: s)
  let small = px <= 32

  // 页面
  let pl: CGFloat = 0.22, pr: CGFloat = 0.84, pb: CGFloat = 0.08, pt: CGFloat = 0.92
  let fold: CGFloat = small ? 0.16 : 0.17, r: CGFloat = 0.035
  let page = CGMutablePath()
  page.move(to: CGPoint(x: pl + r, y: pb))
  page.addLine(to: CGPoint(x: pr - r, y: pb))
  page.addQuadCurve(to: CGPoint(x: pr, y: pb + r), control: CGPoint(x: pr, y: pb))
  page.addLine(to: CGPoint(x: pr, y: pt - fold))
  page.addLine(to: CGPoint(x: pr - fold, y: pt))
  page.addLine(to: CGPoint(x: pl + r, y: pt))
  page.addQuadCurve(to: CGPoint(x: pl, y: pt - r), control: CGPoint(x: pl, y: pt))
  page.addLine(to: CGPoint(x: pl, y: pb + r))
  page.addQuadCurve(to: CGPoint(x: pl + r, y: pb), control: CGPoint(x: pl, y: pb))
  page.closeSubpath()
  g.saveGState()
  g.setShadow(offset: CGSize(width: 0, height: -0.008), blur: small ? 0 : 0.025, color: NSColor(white: 0, alpha: 0.22).cgColor)
  g.addPath(page); g.setFillColor(NSColor.white.cgColor); g.fillPath()
  g.restoreGState()
  g.addPath(page); g.setStrokeColor(NSColor(white: 0, alpha: 0.16).cgColor); g.setLineWidth(max(1 / s, 0.006)); g.strokePath()
  // 折角
  let foldPath = CGMutablePath()
  foldPath.move(to: CGPoint(x: pr - fold, y: pt))
  foldPath.addLine(to: CGPoint(x: pr - fold, y: pt - fold + 0.02))
  foldPath.addQuadCurve(to: CGPoint(x: pr - fold + 0.02, y: pt - fold), control: CGPoint(x: pr - fold, y: pt - fold))
  foldPath.addLine(to: CGPoint(x: pr, y: pt - fold))
  foldPath.closeSubpath()
  g.addPath(foldPath); g.setFillColor(NSColor(white: 0.90, alpha: 1).cgColor); g.fillPath()
  g.addPath(foldPath); g.setStrokeColor(NSColor(white: 0, alpha: 0.12).cgColor); g.strokePath()

  // 正文线条：像一页书
  if !small {
    g.setFillColor(NSColor(white: 0.80, alpha: 1).cgColor)
    let lh: CGFloat = 0.028, gap: CGFloat = 0.062
    var y = pt - fold - 0.06
    var i = 0
    while y > 0.36 {
      // 徽章顶部以下的行从徽章右边起
      let left = y < 0.15 + 0.42 + 0.03 ? 0.10 + 0.42 + 0.06 : pl + 0.08
      let right = i == 0 ? pr - fold - 0.05 : pr - 0.08
      if right - left > 0.05 {
        g.addPath(CGPath(roundedRect: CGRect(x: left, y: y, width: right - left, height: lh), cornerWidth: lh / 2, cornerHeight: lh / 2, transform: nil))
      }
      g.fillPath(); y -= gap; i += 1
    }
  }

  // 徽章：压在页面左下，探出页面左缘（Word 那种做法）
  let bx: CGFloat = small ? 0.06 : 0.10, by: CGFloat = small ? 0.10 : 0.15, bw: CGFloat = small ? 0.58 : 0.42
  let badge = CGPath(roundedRect: CGRect(x: bx, y: by, width: bw, height: bw), cornerWidth: bw * 0.24, cornerHeight: bw * 0.24, transform: nil)
  g.saveGState()
  if !small { g.setShadow(offset: CGSize(width: 0, height: -0.01), blur: 0.03, color: NSColor(red: 0.1, green: 0.3, blue: 0.2, alpha: 0.35).cgColor) }
  g.addPath(badge); g.clip()
  let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [NSColor(srgbRed: 0x2c/255, green: 0x73/255, blue: 0x55/255, alpha: 1).cgColor, NSColor(srgbRed: 0x5f/255, green: 0xb0/255, blue: 0x7a/255, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
  g.drawLinearGradient(grad, start: CGPoint(x: bx, y: by), end: CGPoint(x: bx + bw, y: by + bw), options: [])
  g.restoreGState()

  // 叶子：用图标原稿的路径（1024 画布，y 向下），缩进徽章，白色
  let leaf = CGMutablePath()
  let k = bw / 1024 * 1.25, ox = bx + bw / 2 - 512 * k, oy = by + bw / 2 - 512 * k
  func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * k, y: oy + (1024 - y) * k) }
  leaf.move(to: P(292, 732))
  leaf.addCurve(to: P(744, 280), control1: P(292, 470), control2: P(470, 292))
  leaf.addCurve(to: P(292, 732), control1: P(732, 554), control2: P(554, 732))
  leaf.closeSubpath()
  g.addPath(leaf); g.setFillColor(NSColor.white.cgColor); g.fillPath()
  if px >= 64 {
    g.move(to: P(300, 724)); g.addLine(to: P(600, 424))
    g.setStrokeColor(NSColor(srgbRed: 0x3c/255, green: 0x8a/255, blue: 0x63/255, alpha: 1).cgColor)
    g.setLineWidth(20 * k); g.setLineCap(.round); g.strokePath()
  }

  // 格式标签：页面右下，徽章右边
  if px >= 64 {
    // 文字按像素画：0–1 坐标系里字号太小，排版会取整成 0
    g.saveGState()
    g.scaleBy(x: 1 / s, y: 1 / s)
    let fs = (label.count > 4 ? 0.058 : 0.07) * s
    let str = NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: fs, weight: .semibold), .foregroundColor: NSColor(white: 0.50, alpha: 1), .kern: fs * 0.04])
    let sz = str.size()
    str.draw(at: NSPoint(x: (pr - 0.07) * s - sz.width, y: (pb + 0.075) * s))
    g.restoreGState()
  }
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

for label in CommandLine.arguments.dropFirst() {
  let dir = "\(label).iconset"
  try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
  for base in [16, 32, 128, 256, 512] {
    for (scale, suffix) in [(1, ""), (2, "@2x")] {
      try! render(px: base * scale, label: label).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)\(suffix).png"))
    }
  }
}
