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
guard title.hasPrefix("alice") || title.hasPrefix("hongloumeng") || title.hasPrefix("Leaf") else { print("ABORT: focused window is \(title)"); exit(1) }
// clickpage = 右侧 3/4 垂直居中；clickat <x比例> <y比例> 任意位置；rightclick <x比例> <y比例> 右键
if CommandLine.arguments.count > 1, ["clickpage", "clickat", "rightclick", "dblclick"].contains(CommandLine.arguments[1]) {
    let a = CommandLine.arguments
    let fx = a.count > 3 ? Double(a[2]) ?? 0.75 : 0.75, fy = a.count > 3 ? Double(a[3]) ?? 0.5 : 0.5
    let pos = attr(win, kAXPositionAttribute) as! AXValue, size = attr(win, kAXSizeAttribute) as! AXValue
    var p = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(pos, .cgPoint, &p); AXValueGetValue(size, .cgSize, &sz)
    let pt = CGPoint(x: p.x + sz.width * fx, y: p.y + sz.height * fy)
    let right = a[1] == "rightclick"
    let clicks = a[1] == "dblclick" ? 2 : 1
    for n in 1...clicks {
        for t in right ? [CGEventType.rightMouseDown, .rightMouseUp] : [CGEventType.leftMouseDown, .leftMouseUp] {
            let ev = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: pt, mouseButton: right ? .right : .left)!
            ev.setIntegerValueField(.mouseEventClickState, value: Int64(n))
            ev.post(tap: .cghidEventTap)
            usleep(40_000)
        }
    }
    print("\(a[1]) at \(pt)"); exit(0)
}
func all(_ e: AXUIElement, _ role: String, _ out: inout [AXUIElement]) {
    if attr(e, kAXRoleAttribute) as? String == role { out.append(e) }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { all(c, role, &out) }
}
let args = Array(CommandLine.arguments.dropFirst())
if args.first == "press" {  // press <help 文本>：按工具栏按钮
    var bs: [AXUIElement] = []; all(win, "AXButton", &bs)
    let b = bs.first { e in [kAXHelpAttribute, kAXDescriptionAttribute, kAXTitleAttribute].contains { (attr(e, $0) as? String) == args[1] } }
    if let b { AXUIElementPerformAction(b, kAXPressAction as CFString); print("pressed \(args[1])") } else { print("button not found") }
    exit(0)
}
if args.first == "settext" {  // settext <文本>：给焦点窗口里第一个文本框设值（绕开中文输入法）
    var fs: [AXUIElement] = []; all(win, "AXTextField", &fs)
    guard let f = fs.first else { print("no text field"); exit(1) }
    AXUIElementSetAttributeValue(f, kAXValueAttribute as CFString, args[1] as CFTypeRef)
    print("set text: \(args[1])"); exit(0)
}
if args.first == "popup" {  // popup <第几个弹出按钮> <菜单项标题>
    var ps: [AXUIElement] = []; all(win, "AXPopUpButton", &ps)
    guard let n = Int(args[1]), n <= ps.count else { print("popups: \(ps.count)"); exit(1) }
    let p = ps[n - 1]
    AXUIElementPerformAction(p, kAXPressAction as CFString); usleep(400_000)
    var items: [AXUIElement] = []; all(p, "AXMenuItem", &items)
    if let item = items.first(where: { (attr($0, kAXTitleAttribute) as? String) == args[2] }) {
        AXUIElementPerformAction(item, kAXPressAction as CFString); print("popup \(n) -> \(args[2])")
    } else { print("items: \(items.compactMap { attr($0, kAXTitleAttribute) as? String })") }
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
