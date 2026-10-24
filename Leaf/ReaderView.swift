import OSLog
import SwiftUI
import WebKit

private let log = Logger(subsystem: "com.chengffei.leaf", category: "reader")

struct ReaderView: NSViewRepresentable {
    let book: BookDocument
    let model: ReaderModel
    let prefs: ReaderPrefs

    func makeCoordinator() -> Coordinator { Coordinator(bookID: book.id, model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BookSchemeHandler(book: book.data), forURLScheme: BookSchemeHandler.scheme)
        config.userContentController.add(context.coordinator, name: "leaf")

        let webView = ReaderWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.model = model
        model.webView = webView
        webView.setValue(false, forKey: "drawsBackground") // 加载前不闪白
        #if DEBUG
        webView.isInspectable = true
        #endif

        var url = URLComponents(string: "\(BookSchemeHandler.scheme)://app/reader.html")!
        // 首屏就按当前排版渲染，避免先按默认排一遍再跳
        url.queryItems = [URLQueryItem(name: "prefs", value: prefs.json)]
        if let cfi = ReadingPosition.load(book.id) {
            url.queryItems?.append(URLQueryItem(name: "cfi", value: cfi))
        }
        context.coordinator.applied = prefs
        webView.load(URLRequest(url: url.url!))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.applied != prefs else { return }
        context.coordinator.applied = prefs
        webView.evaluateJavaScript("leaf.setPrefs(\(prefs.json))", completionHandler: nil)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let bookID: String
        private let model: ReaderModel
        /// 已推给页面的排版参数，用于跳过重复推送
        var applied: ReaderPrefs?

        init(bookID: String, model: ReaderModel) {
            self.bookID = bookID
            self.model = model
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "relocate":
                if let cfi = body["cfi"] as? String { ReadingPosition.save(cfi, for: bookID) }
                model.currentHref = body["tocHref"] as? String
            case "toc":
                let items = body["items"] as? [[String: Any]] ?? []
                model.setTOC(items.enumerated().map { index, item in
                    TOCEntry(
                        id: index,
                        label: item["label"] as? String ?? "",
                        href: item["href"] as? String ?? "",
                        depth: item["depth"] as? Int ?? 0
                    )
                })
            case "meta":
                model.title = body["title"] as? String ?? ""
                model.author = body["author"] as? String ?? ""
            case "history":
                model.canGoBack = body["back"] as? Bool ?? false
                model.canGoForward = body["forward"] as? Bool ?? false
            case "toggleTOC":
                model.showsTOC.toggle()
            case "closeTOC":
                if model.showsTOC { model.showsTOC = false }
            case "link":
                if let href = body["href"] as? String, let url = URL(string: href),
                   ["http", "https", "mailto"].contains(url.scheme) {
                    NSWorkspace.shared.open(url)
                }
            case "ready":
                log.info("ready \(String(describing: body), privacy: .public)")
            case "styled":
                log.info("styled \(String(describing: body), privacy: .public)")
            case "error":
                log.error("error \(String(describing: body["message"] ?? ""), privacy: .public)")
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.window?.makeFirstResponder(webView) // 打开即可用键盘翻页
        }

        // WebView 只许加载自家 scheme，书里的外链交给默认浏览器
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            if url.scheme == BookSchemeHandler.scheme || ["blob", "about", "data"].contains(url.scheme ?? "") {
                return .allow
            }
            if action.navigationType == .linkActivated { NSWorkspace.shared.open(url) }
            return .cancel
        }
    }
}

/// 右键菜单换成阅读器自己的：保留系统的拷贝、查询、翻译，去掉「重新载入」之类
final class ReaderWebView: WKWebView {
    weak var model: ReaderModel?

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let keep = menu.items.filter { item in
            let id = item.identifier?.rawValue ?? ""
            return id.hasSuffix("Copy") || id.hasSuffix("LookUp") || id.hasSuffix("Translate")
        }
        guard let model else { return }
        var items = keep
        if !keep.isEmpty { items.append(.separator()) }
        items += [
            ClosureMenuItem("上一页") { model.previousPage() },
            ClosureMenuItem("下一页") { model.nextPage() },
            .separator(),
            ClosureMenuItem(model.showsTOC ? "隐藏目录" : "显示目录", key: "t") { model.showsTOC.toggle() },
            ClosureMenuItem("查找…", key: "f") { model.find() },
        ]
        if model.canGoBack {
            items.append(ClosureMenuItem("返回", key: "[") { model.goBack() })
        }
        items += [
            .separator(),
            ClosureMenuItem("字体与主题…") { model.showsTypography = true },
            ClosureMenuItem("设置…", key: ",") { model.openSettings() },
        ]
        menu.items = items
    }
}

@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, key: String = "", handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { MainActor.assumeIsolated { handler() } }
}
