import Observation
import SwiftUI
import WebKit

struct TOCEntry: Identifiable, Hashable {
    let id: Int
    let label: String
    let href: String
    let depth: Int
}

/// 一个窗口一份：目录、当前章节、侧栏开关，以及回调 JS 的入口。
@MainActor @Observable
final class ReaderModel {
    var toc: [TOCEntry] = []
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
