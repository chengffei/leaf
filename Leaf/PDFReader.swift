import PDFKit
import SwiftUI

/// PDF 走原生 PDFKit：固定版式，字体、行距、版心这些排版设置不适用。
/// 只做阅读器该有的：连续滚动翻页、目录（PDF 书签大纲）、全文查找、缩放、主题着色、记住读到哪页。
struct PDFReaderView: NSViewRepresentable {
    let book: BookDocument
    let model: ReaderModel
    let theme: Theme
    let zoom: Int

    func makeNSView(context: Context) -> PDFView {
        let controller = PDFController(book: book, model: model)
        model.pdf = controller
        controller.apply(theme: theme, zoom: zoom)
        controller.restorePosition()
        return controller.view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        model.pdf?.apply(theme: theme, zoom: zoom)
    }
}

/// 页面着色：PDF 页面本身是白底黑字，画完原页再用混合模式盖一层，得到米黄、墨水屏、深色
final class ThemedPage: PDFPage {
    enum Tint { case none, multiply(CGColor), dark(bg: CGColor, fg: CGColor) }
    nonisolated(unsafe) static var tint: Tint = .none

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        let rect = bounds(for: box)
        context.saveGState()
        defer { context.restoreGState() }
        switch Self.tint {
        case .none:
            break
        case let .multiply(color):
            // 白 → 底色，黑仍是黑
            context.setBlendMode(.multiply)
            context.setFillColor(color)
            context.fill(rect)
        case let .dark(bg, fg):
            // 先反相（白底变黑、黑字变白），再把纯黑抬到深色底、纯白压到浅灰字
            context.setBlendMode(.difference)
            context.setFillColor(.white)
            context.fill(rect)
            context.setBlendMode(.lighten)
            context.setFillColor(bg)
            context.fill(rect)
            context.setBlendMode(.multiply)
            context.setFillColor(fg)
            context.fill(rect)
        }
    }
}

@MainActor
final class PDFController: NSObject, PDFDocumentDelegate {
    let view = LeafPDFView()
    private let document: PDFDocument?
    private let bookID: String
    private weak var model: ReaderModel?
    /// 目录项对应的大纲节点与起始页，下标即 TOCEntry.id
    private var outline: [(item: PDFOutline, page: Int)] = []
    private var hits: [PDFSelection] = []
    /// 命中先攒着，最多每 150 毫秒推一次给列表，免得每条命中都重排一遍 SwiftUI 列表
    private var pendingHits: [SearchHit] = []
    private var flushScheduled = false
    private var observers: [NSObjectProtocol] = []
    private var appliedTheme: Theme?
    private var appliedDark: Bool?
    private var appliedZoom: Int?

    static let zoomRange = 50...300
    static let zoomStep = 10
    /// 查找结果最多列这么多条，再多列表就没法看了
    private static let maxHits = 500

    init(book: BookDocument, model: ReaderModel) {
        let document = PDFDocument(data: book.data)
        self.document = document
        bookID = book.id
        self.model = model
        super.init()
        // 必须在取任何一页之前设好，页面才会按 ThemedPage 创建
        document?.delegate = self

        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.autoScales = true
        view.document = document
        view.model = model
        view.onAppearanceChange = { [weak self] in self?.applyTheme(force: false) }

        loadMeta(fallbackTitle: book.title)
        loadOutline()
        observe()
    }

    nonisolated func classForPage() -> AnyClass { ThemedPage.self }

    // MARK: 元数据与目录

    private func loadMeta(fallbackTitle: String) {
        let attrs = document?.documentAttributes ?? [:]
        let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        model?.title = title.isEmpty ? fallbackTitle : title
        model?.author = (attrs[PDFDocumentAttribute.authorAttribute] as? String) ?? ""
    }

    private func loadOutline() {
        guard let document, let root = document.outlineRoot else { model?.setTOC([]); return }
        var entries: [TOCEntry] = []
        func walk(_ node: PDFOutline, depth: Int) {
            for i in 0..<node.numberOfChildren {
                guard let child = node.child(at: i) else { continue }
                let page = destination(of: child)?.page.map { document.index(for: $0) } ?? -1
                entries.append(TOCEntry(id: entries.count, label: child.label ?? "", href: "\(entries.count)", depth: depth))
                outline.append((child, page))
                walk(child, depth: depth + 1)
            }
        }
        walk(root, depth: 0)
        model?.setTOC(entries)
    }

    private func destination(of item: PDFOutline) -> PDFDestination? {
        item.destination ?? (item.action as? PDFActionGoTo)?.destination
    }

    func goTo(_ entry: TOCEntry) {
        guard let index = Int(entry.href), outline.indices.contains(index),
              let destination = destination(of: outline[index].item) else { return }
        view.go(to: destination)
        view.window?.makeFirstResponder(view)
    }

    // MARK: 进度

    private static let prefix = "pdf:"

    func restorePosition() {
        guard let document, let saved = ReadingPosition.load(bookID), saved.hasPrefix(Self.prefix),
              let index = Int(saved.dropFirst(Self.prefix.count)), let page = document.page(at: index) else {
            pageChanged()
            return
        }
        // 视图还没排版时 go(to:) 不生效，等下一轮
        DispatchQueue.main.async { [weak self] in
            self?.view.go(to: page)
            self?.pageChanged()
        }
    }

    private func pageChanged() {
        guard let document, let page = view.currentPage else { return }
        let index = document.index(for: page)
        ReadingPosition.save("\(Self.prefix)\(index)", for: bookID)
        model?.pageLabel = "\(index + 1) / \(document.pageCount)"
        // 当前章节 = 起始页不超过当前页的最后一个目录项
        let current = outline.indices.last { outline[$0].page >= 0 && outline[$0].page <= index }
        model?.currentHref = current.map { "\($0)" }
    }

    private func observe() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pageChanged() }
            },
            center.addObserver(forName: .PDFViewChangedHistory, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.historyChanged() }
            },
            center.addObserver(forName: .PDFDocumentDidFindMatch, object: document, queue: .main) { [weak self] note in
                nonisolated(unsafe) let selection = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection
                MainActor.assumeIsolated { if let selection { self?.found(selection) } }
            },
            center.addObserver(forName: .PDFDocumentDidEndFind, object: document, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.flushHits(); self?.model?.searchStatus = "done" }
            },
        ]
    }

    private func historyChanged() {
        model?.canGoBack = view.canGoBack
        model?.canGoForward = view.canGoForward
    }

    var pageCount: Int { document?.pageCount ?? 0 }
    func goToPage(_ index: Int) {
        guard let document, let page = document.page(at: min(max(index, 0), document.pageCount - 1)) else { return }
        view.go(to: page)
        view.window?.makeFirstResponder(view)
    }

    func goBack() { view.goBack(nil) }
    func goForward() { view.goForward(nil) }
    func previousPage() { view.goToPreviousPage(nil) }
    func nextPage() { view.goToNextPage(nil) }

    // MARK: 查找

    func search(_ query: String) {
        guard let document, let model else { return }
        document.cancelFindString()
        hits = []
        pendingHits = []
        model.searchHits = []
        model.searchIndex = -1
        view.highlightedSelections = nil
        view.setCurrentSelection(nil, animate: false)
        guard !query.isEmpty else { model.searchStatus = "idle"; return }
        model.searchStatus = "searching"
        document.beginFindString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
    }

    private func found(_ selection: PDFSelection) {
        guard model != nil, hits.count < Self.maxHits else {
            document?.cancelFindString()
            return
        }
        let id = hits.count
        hits.append(selection)
        // 上下文按这一处命中往两边各扩几十个字，不按整行找：同一行有两处命中时，按行找会两条都标成第一处
        let match = selection.string ?? ""
        func around(start: Int, end: Int) -> String {
            guard let copy = selection.copy() as? PDFSelection else { return match }
            copy.extend(atStart: start)
            copy.extend(atEnd: end)
            return (copy.string ?? match).replacingOccurrences(of: "\n", with: " ")
        }
        let pre = String(around(start: 30, end: 0).dropLast(match.count))
        let post = String(around(start: 0, end: 40).dropFirst(match.count))
        let label = document?.outlineItem(for: selection)?.label ?? ""
        pendingHits.append(SearchHit(id: id, cfi: "", label: label, pre: pre, match: match, post: post))
        if id == 0 { flushHits(); goToHit(0); return }
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.flushHits() }
    }

    private func flushHits() {
        flushScheduled = false
        guard !pendingHits.isEmpty else { return }
        model?.searchHits.append(contentsOf: pendingHits)
        pendingHits = []
    }

    func goToHit(_ index: Int) {
        guard hits.indices.contains(index) else { return }
        model?.searchIndex = index
        let selection = hits[index]
        selection.color = .findHighlightColor
        view.setCurrentSelection(selection, animate: true)
        view.go(to: selection)
    }

    func findNext(_ step: Int) {
        guard !hits.isEmpty else { return }
        let current = model?.searchIndex ?? -1
        goToHit(((current + step) % hits.count + hits.count) % hits.count)
    }

    // MARK: 主题与缩放

    func apply(theme: Theme, zoom: Int) {
        if appliedTheme != theme { appliedTheme = theme; applyTheme(force: true) }
        if appliedZoom != zoom {
            appliedZoom = zoom
            if zoom == 100 {
                view.autoScales = true
            } else {
                view.autoScales = false
                view.scaleFactor = view.scaleFactorForSizeToFit * CGFloat(zoom) / 100
            }
        }
    }

    /// 跟随系统时外观变了要重画；其余主题外观固定
    private func applyTheme(force: Bool) {
        guard let theme = appliedTheme else { return }
        let dark: Bool = switch theme {
        case .dark: true
        case .system: view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        default: false
        }
        guard force || dark != appliedDark else { return }
        appliedDark = dark

        let tint: ThemedPage.Tint
        let background: NSColor
        switch theme {
        case .sepia:
            tint = .multiply(NSColor(hex: 0xF4ECD8).cgColor); background = NSColor(hex: 0xE9DFC6)
        case .eink:
            tint = .multiply(NSColor(hex: 0xECEAE4).cgColor); background = NSColor(hex: 0xDCDAD3)
        default:
            if dark {
                tint = .dark(bg: NSColor(hex: 0x1C1C1E).cgColor, fg: NSColor(hex: 0xE5E5E7).cgColor)
                background = NSColor(hex: 0x111112)
            } else {
                tint = .none; background = NSColor(hex: 0xECEBE8)
            }
        }
        ThemedPage.tint = tint
        view.backgroundColor = background
        redraw()
    }

    /// PDFView 缓存了页面位图，换主题后重新挂一次文档才会按新颜色重画；位置保持不变
    private func redraw() {
        guard let document, let page = view.currentPage, view.window != nil else { return }
        let point = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.maxY), to: page)
        let scale = view.scaleFactor, autoScales = view.autoScales
        view.document = nil
        view.document = document
        view.autoScales = autoScales
        if !autoScales { view.scaleFactor = scale }
        view.go(to: PDFDestination(page: page, at: point))
    }
}

/// PDFView 小改：外观变化回调（跟随系统主题），右键菜单换成阅读器自己的
final class LeafPDFView: PDFView {
    weak var model: ReaderModel?
    var onAppearanceChange: () -> Void = {}

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(self) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        if let text = currentSelection?.string, !text.isEmpty {
            menu.addItem(ClosureMenuItem(String(localized: "Copy"), key: "c") { [weak self] in self?.copy(nil) })
            menu.addItem(.separator())
        }
        guard let model else { return menu }
        menu.items += [
            ClosureMenuItem(String(localized: "Previous Page")) { model.previousPage() },
            ClosureMenuItem(String(localized: "Next Page")) { model.nextPage() },
            .separator(),
            ClosureMenuItem(String(localized: model.showsTOC && model.panelTab == .toc ? "Hide Contents" : "Show Contents"), key: "t") { model.toggleTOC() },
            ClosureMenuItem(String(localized: "Find…"), key: "f") { model.find() },
            .separator(),
            ClosureMenuItem(String(localized: "Size and Theme…")) { model.showsTypography = true },
            ClosureMenuItem(String(localized: "Settings…"), key: ",") { model.openSettings() },
        ]
        return menu
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
