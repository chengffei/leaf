import Foundation
import UniformTypeIdentifiers
import WebKit

/// `leaf://app/…` 读 bundle 里的 Web 目录，`leaf://app/book` 给出当前这本书的字节（同源，fetch 才不被拦）。
@MainActor
final class BookSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "leaf"

    private let book: Data
    private let webRoot = Bundle.main.resourceURL!.appendingPathComponent("Web", isDirectory: true)

    init(book: Data) {
        self.book = book
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let body: Data?
        let mime: String
        if url.path == "/book" {
            body = book
            mime = "application/octet-stream"
        } else {
            let file = webRoot.appendingPathComponent(String(url.path.dropFirst())).standardizedFileURL
            body = file.path.hasPrefix(webRoot.path) ? try? Data(contentsOf: file) : nil
            mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        }
        guard let body else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime, "Content-Length": "\(body.count)"]
        )!
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
