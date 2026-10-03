import AppKit
import ApplicationServices
// 用法: ax.swift [selectRow]
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.chengffei.leaf").first!
let root = AXUIElementCreateApplication(app.processIdentifier)
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? {
    var v: AnyObject?; AXUIElementCopyAttributeValue(e, a as CFString, &v); return v
}
func find(_ e: AXUIElement, _ role: String) -> AXUIElement? {
    if attr(e, kAXRoleAttribute) as? String == role { return e }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { if let f = find(c, role) { return f } }
    return nil
}
func texts(_ e: AXUIElement) -> [String] {
    var out: [String] = []
    if attr(e, kAXRoleAttribute) as? String == "AXStaticText", let v = attr(e, kAXValueAttribute) as? String { out.append(v) }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { out += texts(c) }
    return out
}
let win = (attr(root, kAXFocusedWindowAttribute) as! AXUIElement)
let title = attr(win, kAXTitleAttribute) as? String ?? ""
// 安全闸：只对测试书窗口动手，防止误碰用户正在读的书
guard title.hasPrefix("alice") || title.hasPrefix("hongloumeng") else { print("ABORT: focused window is \(title)"); exit(1) }
if CommandLine.arguments.count > 1, CommandLine.arguments[1] == "clickpage" {
    // 真实鼠标点击：窗口右侧 3/4、垂直居中
    let pos = attr(win, kAXPositionAttribute) as! AXValue, size = attr(win, kAXSizeAttribute) as! AXValue
    var p = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(pos, .cgPoint, &p); AXValueGetValue(size, .cgSize, &sz)
    let pt = CGPoint(x: p.x + sz.width * 0.75, y: p.y + sz.height * 0.5)
    for t in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: pt, mouseButton: .left)!.post(tap: .cghidEventTap)
        usleep(50_000)
    }
    print("clicked page at \(pt)"); exit(0)
}
func all(_ e: AXUIElement, _ role: String, _ out: inout [AXUIElement]) {
    if attr(e, kAXRoleAttribute) as? String == role { out.append(e) }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { all(c, role, &out) }
}
let args = Array(CommandLine.arguments.dropFirst())
if args.first == "press" {  // press <help 文本>：按工具栏按钮
    var bs: [AXUIElement] = []; all(win, "AXButton", &bs)
    let b = bs.first { (attr($0, kAXHelpAttribute) as? String) == args[1] || (attr($0, kAXDescriptionAttribute) as? String) == args[1] }
    if let b { AXUIElementPerformAction(b, kAXPressAction as CFString); print("pressed \(args[1])") } else { print("button not found") }
    exit(0)
}
if args.first == "segment" {  // segment <第几个分段控件> <第几段>，从 1 数
    var gs: [AXUIElement] = []; all(root, "AXRadioGroup", &gs)
    guard let g = Int(args[1]), g <= gs.count else { print("groups: \(gs.count)"); exit(1) }
    let btns = (attr(gs[g - 1], kAXChildrenAttribute) as? [AXUIElement]) ?? []
    let b = btns[Int(args[2])! - 1]
    AXUIElementPerformAction(b, kAXPressAction as CFString)
    print("segment \(g) -> \(attr(b, kAXTitleAttribute) as? String ?? attr(b, kAXDescriptionAttribute) as? String ?? "?")")
    exit(0)
}
guard let outline = find(win, "AXOutline") else { print("sidebar: hidden (no outline)"); exit(0) }
let rows = (attr(outline, kAXRowsAttribute) as? [AXUIElement]) ?? []
let selected = (attr(outline, kAXSelectedRowsAttribute) as? [AXUIElement]) ?? []
let selIdx = selected.first.flatMap { s in rows.firstIndex { CFEqual($0, s) } }
print("rows: \(rows.count), selected: \(selIdx.map { "\($0 + 1) \(texts(rows[$0]).first ?? "")" } ?? "none")")
print("first: \(rows.prefix(4).map { texts($0).first ?? "?" })")
if CommandLine.arguments.count > 1, let n = Int(CommandLine.arguments[1]), n <= rows.count {
    AXUIElementSetAttributeValue(outline, kAXSelectedRowsAttribute as CFString, [rows[n - 1]] as CFArray)
    print("clicked row \(n): \(texts(rows[n - 1]).first ?? "")")
}
