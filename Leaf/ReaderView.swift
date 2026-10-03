import OSLog
import SwiftUI
import WebKit

private let log = Logger(subsystem: "com.chengffei.leaf", category: "reader")

struct ReaderView: NSViewRepresentable {
    let book: BookDocument
    let model: ReaderModel
    let zoom: Double
    let lineSpacing: LineSpacing
    let font: ReaderFont

    func makeCoordinator() -> Coordinator { Coordinator(bookID: book.id, model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BookSchemeHandler(book: book.data), forURLScheme: BookSchemeHandler.scheme)
        config.userContentController.add(context.coordinator, name: "leaf")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.pageZoom = zoom
        model.webView = webView
        webView.setValue(false, forKey: "drawsBackground") // 加载前不闪白
        #if DEBUG
        webView.isInspectable = true
        #endif

        var url = URLComponents(string: "\(BookSchemeHandler.scheme)://app/reader.html")!
        // 首屏就按当前排版渲染，避免先按默认排一遍再跳
        url.queryItems = [
            URLQueryItem(name: "lh", value: String(lineSpacing.rawValue)),
            URLQueryItem(name: "font", value: font.rawValue),
        ]
        if let cfi = ReadingPosition.load(book.id) {
            url.queryItems?.append(URLQueryItem(name: "cfi", value: cfi))
        }
        context.coordinator.applied = (lineSpacing, font)
        webView.load(URLRequest(url: url.url!))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        let coordinator = context.coordinator
        guard coordinator.applied.0 != lineSpacing || coordinator.applied.1 != font else { return }
        coordinator.applied = (lineSpacing, font)
        webView.evaluateJavaScript(
            "leaf.setPrefs({ lineHeight: \(lineSpacing.rawValue), font: '\(font.rawValue)' })",
            completionHandler: nil
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let bookID: String
        private let model: ReaderModel
        var applied: (LineSpacing, ReaderFont) = (.standard, .original)

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
                model.toc = items.enumerated().map { index, item in
                    TOCEntry(
                        id: index,
                        label: item["label"] as? String ?? "",
                        href: item["href"] as? String ?? "",
                        depth: item["depth"] as? Int ?? 0
                    )
                }
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
