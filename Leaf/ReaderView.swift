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
        model.bookID = book.id
        webView.setValue(false, forKey: "drawsBackground") // 加载前不闪白
        #if DEBUG
        webView.isInspectable = true
        #endif

        var url = URLComponents(string: "\(BookSchemeHandler.scheme)://app/reader.html")!
        // 首屏就按当前排版渲染，避免先按默认排一遍再跳
        url.queryItems = [URLQueryItem(name: "prefs", value: prefs.json)]
        #if DEBUG
        url.queryItems?.append(URLQueryItem(name: "debug", value: "1")) // 页面回报实际排版（styled 日志）
        #endif
        if !book.format.isEmpty {
            url.queryItems?.append(URLQueryItem(name: "format", value: book.format))
            url.queryItems?.append(URLQueryItem(name: "title", value: book.title))
        }
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
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(historyCleared), name: .readingHistoryCleared, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(annotationsDeleted), name: .annotationsDeleted, object: nil)
        }

        @objc private func historyCleared(_ note: Notification) {
            model.webView?.evaluateJavaScript("leaf.resetSpeed()", completionHandler: nil)
        }

        @objc private func annotationsDeleted(_ note: Notification) { model.annotationsDeleted() }

        private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
        private func annotation(from body: [String: Any]) -> Annotation? {
            guard let item = body["item"], let data = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? Self.decoder.decode(Annotation.self, from: data)
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
                model.description = body["description"] as? String ?? ""
            case "annotation":
                guard let item = annotation(from: body) else { return }
                switch body["action"] as? String {
                case "update": model.update(item)
                case "remove": model.removed(item.id)
                default: model.add(item)
                }
            case "copy":
                if let text = body["text"] as? String, !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            case "order":
                model.setOrder(body["ids"] as? [String] ?? [])
            case "bookmarked":
                let value = body["value"] as? Bool ?? false
                if model.isBookmarked != value { model.isBookmarked = value }
            case "lookup":
                // 系统词典弹窗：点在选区的位置。WKWebView 是翻转坐标系，网页坐标直接用
                guard let text = body["text"] as? String, !text.isEmpty, let webView = model.webView else { return }
                let x = body["x"] as? Double ?? 0, y = body["y"] as? Double ?? 0
                let point = webView.isFlipped ? NSPoint(x: x, y: y) : NSPoint(x: x, y: webView.bounds.height - y)
                webView.showDefinition(for: NSAttributedString(string: text), at: point)
            case "history":
                model.canGoBack = body["back"] as? Bool ?? false
                model.canGoForward = body["forward"] as? Bool ?? false
            case "toggleTOC":
                model.toggleTOC()
            case "search":
                // @Observable 每次赋值都会让面板重绘，值没变就不写
                let status = body["status"] as? String ?? "idle", index = body["index"] as? Int ?? -1
                let truncated = body["truncated"] as? Bool ?? false
                if model.searchStatus != status { model.searchStatus = status }
                if model.searchIndex != index { model.searchIndex = index }
                if model.searchTruncated != truncated { model.searchTruncated = truncated }
                // 页面只推新增的结果；offset 对不上（中途换了关键词）就整表重来
                let offset = body["offset"] as? Int ?? 0
                let hits = (body["results"] as? [[String: Any]] ?? []).enumerated().map { i, h in
                    SearchHit(id: offset + i, cfi: h["cfi"] as? String ?? "", label: h["label"] as? String ?? "",
                              pre: h["pre"] as? String ?? "", match: h["match"] as? String ?? "", post: h["post"] as? String ?? "")
                }
                if offset == 0 { model.searchHits = hits }
                else if offset == model.searchHits.count { if !hits.isEmpty { model.searchHits.append(contentsOf: hits) } }
            case "closeTOC":
                if model.showsTOC { model.showsTOC = false }
            case "link":
                if let href = body["href"] as? String, let url = URL(string: href),
                   ["http", "https", "mailto"].contains(url.scheme) {
                    NSWorkspace.shared.open(url)
                }
            case "ready":
                log.info("ready \(String(describing: body), privacy: .public)")
                model.loadAnnotations()
                #if DEBUG
                let seed = UserDefaults.standard.integer(forKey: "LeafDebugSeed")
                if seed > 0 { model.webView?.evaluateJavaScript("leaf.debugSeed(\(seed), \(seed / 10))", completionHandler: nil) }
                #endif
            case "perf":
                log.info("perf \(String(describing: body), privacy: .public)")
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
            ClosureMenuItem(String(localized: "Previous Page")) { model.previousPage() },
            ClosureMenuItem(String(localized: "Next Page")) { model.nextPage() },
            .separator(),
            ClosureMenuItem(String(localized: model.showsTOC && model.panelTab == .toc ? "Hide Contents" : "Show Contents"), key: "t") { model.toggleTOC() },
            ClosureMenuItem(String(localized: "Find…"), key: "f") { model.find() },
        ]
        if model.canGoBack {
            items.append(ClosureMenuItem(String(localized: "Back"), key: "[") { model.goBack() })
        }
        items += [
            .separator(),
            ClosureMenuItem(String(localized: "Size and Theme…")) { model.showsTypography = true },
            ClosureMenuItem(String(localized: "Settings…"), key: ",") { model.openSettings() },
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
