import Observation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum PanelTab: String, CaseIterable, Identifiable {
    case toc, search, notes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .toc: String(localized: "Contents")
        case .search: String(localized: "Find")
        case .notes: String(localized: "Notes")
        }
    }
}

struct SearchHit: Identifiable, Hashable {
    let id: Int
    let cfi: String
    let label: String // 所在章节
    let pre: String
    let match: String
    let post: String
}

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
    /// 浮动面板开关（目录或查找）。告诉 JS：面板开着时点正文只收面板，不翻页
    var showsTOC = false {
        didSet { if showsTOC != oldValue { call("leaf.setPanelOpen(\(showsTOC))") } }
    }
    var panelTab: PanelTab = .toc
    var searchQuery = ""
    var searchHits: [SearchHit] = []
    var searchIndex = -1
    /// 命中太多，只列了前面一部分（EPUB、PDF 都是 500 处）
    var searchTruncated = false
    var searchStatus = "idle" // idle / searching / done，由 JS 回报
    var title = ""
    var author = ""
    /// 元数据里的简介，去掉了 HTML 标签；没有就空
    var description = ""
    /// 内容哈希，标注文件按它存
    @ObservationIgnored var bookID = ""
    /// 高亮、笔记、书签，按在书里的先后排（JS 回报时已排好）
    private(set) var annotations: [Annotation] = []
    /// 当前页上有书签：工具栏与菜单据此显示「移除书签」
    var isBookmarked = false
    var canGoBack = false
    var canGoForward = false
    var hoversTop = false // 鼠标在窗口顶部，用来浮现红绿灯与工具栏
    var showsTypography = false // 工具栏 Aa 弹层
    @ObservationIgnored weak var webView: WKWebView?
    /// PDF 窗口才有；有它时翻页、目录、查找都交给 PDFKit，不调 JS
    @ObservationIgnored var pdf: PDFController? { didSet { isPDF = pdf != nil } }
    private(set) var isPDF = false
    /// PDF 的「第几页 / 共几页」，显示在右下角
    var pageLabel = ""
    /// PDF 缩放：相对「适合宽度」的百分比，只管这个窗口，不影响 EPUB 字号
    var pdfZoom = 100
    var canZoomIn: Bool { isPDF ? pdfZoom < PDFController.zoomRange.upperBound : ReaderSettings.shared.canZoomIn }
    var canZoomOut: Bool { isPDF ? pdfZoom > PDFController.zoomRange.lowerBound : ReaderSettings.shared.canZoomOut }
    func zoomIn() {
        if isPDF { pdfZoom = min(pdfZoom + PDFController.zoomStep, PDFController.zoomRange.upperBound) }
        else { ReaderSettings.shared.zoomIn() }
    }
    func zoomOut() {
        if isPDF { pdfZoom = max(pdfZoom - PDFController.zoomStep, PDFController.zoomRange.lowerBound) }
        else { ReaderSettings.shared.zoomOut() }
    }
    func resetZoom() { if isPDF { pdfZoom = 100 } else { ReaderSettings.shared.resetZoom() } }
    /// 打开「设置」窗口：SwiftUI 的 openSettings 只能从环境里取，由 BookWindow 塞进来给右键菜单用
    @ObservationIgnored var openSettings: @MainActor () -> Void = {}

    /// href → 目录项；合集目录上千条，每次翻页、每次重绘都线性找一遍太浪费
    @ObservationIgnored private var tocIndex: [String: TOCEntry.ID] = [:]

    var currentID: TOCEntry.ID? {
        guard let currentHref else { return nil }
        return tocIndex[currentHref]
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
        tocIndex = [:]
        for entry in result where tocIndex[entry.href] == nil { tocIndex[entry.href] = entry.id } // 同一 href 取第一条，和原来的 first 一致
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
        if let pdf { pdf.goTo(entry); return }
        guard let webView,
              let arg = try? JSONEncoder().encode(entry.href),
              let json = String(data: arg, encoding: .utf8) else { return }
        webView.evaluateJavaScript("leaf.goTo(\(json))", completionHandler: nil)
        webView.window?.makeFirstResponder(webView) // 跳完继续用键盘翻页
    }

    func goBack() { if let pdf { pdf.goBack() } else { call("leaf.back()") } }
    func goForward() { if let pdf { pdf.goForward() } else { call("leaf.forward()") } }
    func previousPage() { if let pdf { pdf.previousPage() } else { call("leaf.prev()") } }
    func nextPage() { if let pdf { pdf.nextPage() } else { call("leaf.next()") } }
    /// ⌘F：打开面板的查找页；查找框的聚焦由面板自己处理
    func find() {
        panelTab = .search
        showsTOC = true
    }
    func toggleTOC() {
        if showsTOC && panelTab == .toc { showsTOC = false } else { panelTab = .toc; showsTOC = true }
    }
    func search(_ query: String) {
        searchQuery = query
        if let pdf { pdf.search(query); return }
        guard let arg = try? JSONEncoder().encode(query), let json = String(data: arg, encoding: .utf8) else { return }
        call("leaf.search(\(json))")
    }
    func findNext() { if let pdf { pdf.findNext(1) } else { call("leaf.findNext(1)") } }
    func findPrevious() { if let pdf { pdf.findNext(-1) } else { call("leaf.findNext(-1)") } }
    func goToHit(_ index: Int) { if let pdf { pdf.goToHit(index) } else { call("leaf.goToResult(\(index))") } }
    /// ⌘L：EPUB 由页面弹跳转小条；PDF 弹原生对话框输页码
    func goToPrompt() { if isPDF { showsPageJump = true } else { call("leaf.goToPrompt()") } }
    var showsPageJump = false
    var pageCount: Int { pdf?.pageCount ?? 0 }
    func goToPage(_ text: String) {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)) else { return }
        pdf?.goToPage(n - 1)
    }

    // MARK: 标注

    /// 开书时从磁盘读，推给页面画出来
    func loadAnnotations() {
        annotations = AnnotationStore.load(bookID)
        pushAnnotations()
    }

    private func pushAnnotations() {
        guard let json = encode(annotations) else { return }
        call("leaf.setAnnotations(\(json))")
    }

    /// 页面新建了高亮或书签（JS 已算好 CFI、原文、章节、位置号）
    func add(_ annotation: Annotation) {
        annotations.append(annotation)
        sortAndSave()
    }

    func update(_ annotation: Annotation) {
        guard let i = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations[i] = annotation
        sortAndSave()
        pushAnnotations()
    }

    /// 页面自己删掉了（卡片上的「删除」、再按 ⌘D）：只更新内存和磁盘
    func removed(_ id: UUID) {
        annotations.removeAll { $0.id == id }
        sortAndSave()
    }

    func remove(_ annotation: Annotation) {
        annotations.removeAll { $0.id == annotation.id }
        sortAndSave()
        guard let json = encode(annotation.id.uuidString) else { return }
        call("leaf.removeAnnotation(\(json))")
    }

    /// 页面按书内顺序回报：JS 比较 CFI 比 Swift 方便
    func setOrder(_ ids: [String]) {
        let rank = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        annotations.sort { (rank[$0.id.uuidString] ?? .max) < (rank[$1.id.uuidString] ?? .max) }
        sortAndSave()
    }

    private func sortAndSave() {
        AnnotationStore.save(annotations, for: bookID)
    }

    /// 导出：Markdown 或 Kindle 的 My Clippings，走系统存储面板
    func export(clippings: Bool) {
        let panel = NSSavePanel()
        let base = title.isEmpty ? String(localized: "Notes") : title
        panel.nameFieldStringValue = clippings ? "My Clippings.txt" : "\(base).md"
        panel.allowedContentTypes = [clippings ? .plainText : .init(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard let window = webView?.window else { return }
        panel.beginSheetModal(for: window) { [self] response in
            guard response == .OK, let url = panel.url else { return }
            let text = clippings
                ? AnnotationExport.clippings(annotations, title: title, author: author)
                : AnnotationExport.markdown(annotations, title: title, author: author)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 设置里删光了：清内存并让页面擦掉
    func annotationsDeleted() {
        annotations = []
        pushAnnotations()
    }

    func goTo(_ annotation: Annotation) {
        guard let json = encode(annotation.cfi) else { return }
        call("leaf.showAnnotation(\(json))")
        // 面板里的列表点过之后还握着键盘焦点，面板收起后再把焦点还给书页，方向键才能翻页
        DispatchQueue.main.async { [weak self] in self?.webView?.window?.makeFirstResponder(self?.webView) }
    }

    /// ⌘D：当页有书签就移除，没有就加
    func toggleBookmark() { if !isPDF { call("leaf.toggleBookmark()") } }

    /// ⌃⌘D 或选区小条上的「查词」：让页面回报选中的词和位置，再弹系统词典
    func lookUp() { if !isPDF { call("leaf.lookUpSelection()") } }

    func setChromeVisible(_ visible: Bool) { if !isPDF { call("leaf.setChromeVisible(\(visible))") } }

    var highlightCount: Int { annotations.filter { $0.kind == .highlight }.count }

    private func encode<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func call(_ js: String) { webView?.evaluateJavaScript(js, completionHandler: nil) }
}

extension FocusedValues {
    @Entry var reader: ReaderModel?
}
