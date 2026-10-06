import Observation
import SwiftUI
import WebKit

struct TOCEntry: Identifiable, Hashable {
    let id: Int
    let label: String
    let href: String
    let depth: Int
    var parent: Int? = nil
    var hasChildren = false
}

/// 一个窗口一份：目录、当前章节、侧栏开关，以及回调 JS 的入口。
@MainActor @Observable
final class ReaderModel {
    private(set) var toc: [TOCEntry] = []
    /// 展开着的目录项。目录短就全部展开；长（多本合集等）就只展开当前在读的那一支
    var expanded: Set<TOCEntry.ID> = []
    var currentHref: String?
    var showsTOC = false
    var title = ""
    var author = ""
    var canGoBack = false
    var canGoForward = false
    var hoversTop = false // 鼠标在窗口顶部，用来浮现红绿灯与工具栏
    @ObservationIgnored weak var webView: WKWebView?

    var currentID: TOCEntry.ID? {
        guard let currentHref else { return nil }
        return toc.first { $0.href == currentHref }?.id
    }

    static let collapseThreshold = 50

    /// JS 回传的是压平的目录（按深度缩进），这里补上父子关系
    func setTOC(_ entries: [TOCEntry]) {
        var result = entries
        var stack: [Int] = [] // 当前路径上各层的祖先
        for i in result.indices {
            while let last = stack.last, result[last].depth >= result[i].depth { stack.removeLast() }
            if let parent = stack.last {
                result[i].parent = parent
                result[parent].hasChildren = true
            }
            stack.append(i)
        }
        toc = result
        expanded = result.count > Self.collapseThreshold
            ? [] : Set(result.filter(\.hasChildren).map(\.id))
        revealCurrent()
    }

    /// 有没有层级：完全扁平的目录不给三角留位置
    var isNested: Bool { toc.contains(where: \.hasChildren) }

    /// 侧栏里看得见的条目：祖先全部展开的才显示
    var visibleTOC: [TOCEntry] {
        toc.filter { isVisible($0.id) }
    }

    private func isVisible(_ id: TOCEntry.ID) -> Bool {
        var parent = toc[id].parent
        while let p = parent {
            if !expanded.contains(p) { return false }
            parent = toc[p].parent
        }
        return true
    }

    /// 当前章节被收在折叠里时，高亮它最近的可见祖先（不强行展开，免得和手动收起打架）
    var visibleCurrentID: TOCEntry.ID? {
        var id = currentID
        while let i = id, !isVisible(i) { id = toc[i].parent }
        return id
    }

    /// 展开到当前章节：打开侧栏、载入目录时用
    func revealCurrent() {
        var parent = currentID.flatMap { toc[$0].parent }
        while let p = parent {
            expanded.insert(p)
            parent = toc[p].parent
        }
    }

    func toggle(_ id: TOCEntry.ID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    func goTo(_ entry: TOCEntry) {
        guard let webView,
              let arg = try? JSONEncoder().encode(entry.href),
              let json = String(data: arg, encoding: .utf8) else { return }
        webView.evaluateJavaScript("leaf.goTo(\(json))", completionHandler: nil)
        webView.window?.makeFirstResponder(webView) // 跳完继续用键盘翻页
    }

    func goBack() { webView?.evaluateJavaScript("leaf.back()", completionHandler: nil) }
    func goForward() { webView?.evaluateJavaScript("leaf.forward()", completionHandler: nil) }
}

extension FocusedValues {
    @Entry var reader: ReaderModel?
}
