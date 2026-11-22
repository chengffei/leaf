import SwiftUI

struct BookWindow: View {
    let book: BookDocument
    @State private var model = ReaderModel()
    /// 开书先亮出红绿灯与工具栏 3 秒再淡出，让人知道按钮在哪
    @State private var introducing = true
    @State private var pageText = ""
    @State private var asksDefault = false
    @Environment(\.openSettings) private var openSettings
    private let settings = ReaderSettings.shared

    var body: some View {
        // 目录是浮动面板，盖在正文上：推挤式侧栏会让书重新分页，读者刚看到的那页就变了
        ZStack(alignment: .topLeading) {
            Group {
                if book.isPDF {
                    PDFReaderView(book: book, model: model, theme: settings.theme, zoom: model.pdfZoom)
                        .overlay(alignment: .bottomTrailing) { PageLabel(model: model) }
                } else {
                    ReaderView(book: book, model: model, prefs: settings.prefs)
                }
            }
            // 铺到窗口顶部（标题文字已移除，按钮悬停才浮现）
            .ignoresSafeArea(.container, edges: .top)
            if model.showsTOC {
                TOCPanel(model: model)
                    .id("panel")
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if asksDefault {
                DefaultReaderPrompt { asksDefault = false }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showsTOC)
        .animation(.easeOut(duration: 0.25), value: asksDefault)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { model.toggleTOC() } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Contents ⌘T")
            }
            // 标题隐藏后工具栏会向左收拢，用弹性间隔把 Aa 推回右上角
            if #available(macOS 26.0, *) { ToolbarSpacer(.flexible) }
            ToolbarItem(placement: .primaryAction) {
                Button { model.showsTypography.toggle() } label: {
                    // 衬线 Aa：比 SF Symbol 的大小两个 A 轻，也更像阅读器；不随语言本地化
                    Text(verbatim: "Aa")
                        .font(.system(size: 18, design: .serif))
                }
                .help("Size and Theme")
                .accessibilityLabel("Size and Theme")
                .popover(isPresented: $model.showsTypography, arrowEdge: .bottom) {
                    TypographyPanel(model: model)
                }
            }
        }
        .background(
            WindowChrome(
                visible: introducing || model.showsTOC || model.hoversTop || model.showsTypography,
                title: model.title
            ) { hovering in
                if model.hoversTop != hovering { model.hoversTop = hovering }
            }
            .ignoresSafeArea()
        )
        .task {
            try? await Task.sleep(for: .seconds(3))
            introducing = false
        }
        .task {
            // 等书翻开、工具栏淡出后再问，别和开书抢注意力
            guard book.isEPUB, DefaultReader.shouldAsk else { return }
            try? await Task.sleep(for: .seconds(3.5))
            DefaultReader.markAsked()
            asksDefault = true
        }
        .alert("Go to Page", isPresented: $model.showsPageJump) {
            TextField("", text: $pageText)
            Button("Go") { model.goToPage(pageText); pageText = "" }
            Button("Cancel", role: .cancel) { pageText = "" }
        } message: {
            Text("Page 1 to \(model.pageCount)")
        }
        .focusedSceneValue(\.reader, model)
        .onAppear { model.openSettings = { openSettings() } }
        // 主题的浅色 / 深色：改窗口外观，WebView 的 prefers-color-scheme 跟着窗口走；米黄按浅色
        .preferredColorScheme(settings.theme.colorScheme)
    }
}

/// 双击 EPUB 默认进「图书」，「双击就读」就落空了。第一次在 Leaf 里读 EPUB 时问一次，以后不再问
@MainActor
enum DefaultReader {
    private static let askedKey = "askedDefaultEPUB"

    static var shouldAsk: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "LeafForceDefaultPrompt") { return true } // 测试用
        #endif
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return false }
        guard let app = NSWorkspace.shared.urlForApplication(toOpen: .epub) else { return true }
        return Bundle(url: app)?.bundleIdentifier != Bundle.main.bundleIdentifier
    }

    static func markAsked() { UserDefaults.standard.set(true, forKey: askedKey) }

    /// 系统会弹窗让用户确认；用户拒绝会抛错，照常忽略
    static func makeDefault() async {
        try? await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .epub)
    }
}

/// 书页底部的一条轻提示，不挡正文中间
struct DefaultReaderPrompt: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Open EPUB books in Leaf when you double-click them?")
                .font(.callout)
            Button("Not Now", action: dismiss)
                .controlSize(.small)
            Button("Use Leaf") {
                dismiss()
                Task { await DefaultReader.makeDefault() }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        }
        .padding(.leading, 18).padding(.trailing, 10).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
        .padding(.bottom, 44)
    }
}

/// PDF 页码：单独成视图，滚动翻页时只重绘这一小块，不连带整个窗口
struct PageLabel: View {
    let model: ReaderModel

    var body: some View {
        Text(model.pageLabel)
            .font(.caption).monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .padding(12)
            .allowsHitTesting(false)
    }
}

/// 浮动面板：固定宽度的玻璃面板，贴左侧，上不压标题栏按钮，下不压状态行；目录与查找两页
struct TOCPanel: View {
    @Bindable var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("Panel", selection: $model.panelTab) {
                ForEach(PanelTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            switch model.panelTab {
            case .toc: TOCSidebar(model: model)
            case .search: SearchPanel(model: model)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        .padding(.leading, 12)
        .padding(.top, 12)
        .padding(.bottom, 44)
    }
}

/// 查找页：输入即搜（停 300 毫秒），Enter 下一处，结果按章节分组，点一条跳过去
struct SearchPanel: View {
    @Bindable var model: ReaderModel
    @State private var text = ""
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // 系统搜索框：带放大镜与清除按钮；Esc 先清空，空了再按关掉面板
                SearchField(text: $text, prompt: String(localized: "Find")) {
                    text == model.searchQuery ? model.findNext() : model.search(text)
                } onCancel: {
                    model.showsTOC = false
                }
                Text(countText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .frame(minWidth: 44, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if model.searchHits.isEmpty {
                ContentUnavailableView(
                    model.searchStatus == "done" && !model.searchQuery.isEmpty ? "Nothing Found" : "Search the Whole Book",
                    systemImage: "magnifyingglass"
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: hitSelection) {
                    ForEach(groups, id: \.first) { group in
                        Section(group.label.isEmpty ? String(localized: "Body") : group.label) {
                            ForEach(group.hits) { hit in
                                excerpt(hit).tag(hit.id).lineLimit(3)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear { text = model.searchQuery }
        .onChange(of: text) { _, new in
            debounce?.cancel()
            debounce = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let q = new.trimmingCharacters(in: .whitespaces)
                if q != model.searchQuery { model.search(q) }
            }
        }
    }

    private var countText: String {
        switch model.searchStatus {
        case "searching": model.searchHits.isEmpty ? String(localized: "Searching") : "\(model.searchHits.count)…"
        case "done": model.searchHits.isEmpty ? "" : "\(model.searchIndex + 1) / \(model.searchHits.count)\(model.searchTruncated ? "+" : "")"
        default: ""
        }
    }

    // 按原始章名分组：比较时别用替换成「正文」后的名字，否则没有章名的命中会各成一组；
    // 不同位置可能出现同名章节，分组的 id 用首条命中的序号
    private struct Group { let label: String; let first: Int; var hits: [SearchHit] }
    private var groups: [Group] {
        var out: [Group] = []
        for hit in model.searchHits {
            if out.last?.label == hit.label { out[out.count - 1].hits.append(hit) }
            else { out.append(Group(label: hit.label, first: hit.id, hits: [hit])) }
        }
        return out
    }

    private func excerpt(_ hit: SearchHit) -> Text {
        Text(hit.pre).foregroundStyle(.secondary) + Text(hit.match).bold() + Text(hit.post).foregroundStyle(.secondary)
    }

    private var hitSelection: Binding<Int?> {
        Binding(
            get: { model.searchIndex >= 0 ? model.searchIndex : nil },
            set: { if let i = $0 { model.goToHit(i) } }
        )
    }
}

struct TOCSidebar: View {
    let model: ReaderModel

    var body: some View {
        // 头部放在列表外面：放进 safeAreaInset 时列表会从书名底下滚过去，两者叠在一起
        VStack(alignment: .leading, spacing: 0) {
            header
            if model.toc.isEmpty {
                ContentUnavailableView("No Contents", systemImage: "list.bullet")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(model.visibleTOC, selection: selection) { entry in
                        row(entry)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .onAppear { reveal(proxy) }
                    .onChange(of: model.showsTOC) { reveal(proxy) }
                }
            }
        }
    }

    private func row(_ entry: TOCEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // 三角只管展开收起，不跳转；没有下级的留同宽空位，同层文字对齐
            if entry.hasChildren {
                Button { withAnimation(.easeOut(duration: 0.15)) { model.toggle(entry.id) } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(model.expanded.contains(entry.id) ? 90 : 0))
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if model.isNested {
                Color.clear.frame(width: 12, height: 1)
            }
            Text(entry.label)
                .lineLimit(2)
                .help(entry.label)
        }
        .padding(.leading, CGFloat(entry.depth) * 14)
    }

    @ViewBuilder private var header: some View {
        if !model.title.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.headline)
                    .lineLimit(2)
                if !model.author.isEmpty {
                    Text(model.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .help(model.author.isEmpty ? model.title : "\(model.title)\n\(model.author)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }

    // 读取 = 当前章节（收在折叠里就是它的可见祖先）；写入 = 用户点了某条 → 跳转并收起面板，有下级的顺带展开
    private var selection: Binding<TOCEntry.ID?> {
        Binding(
            get: { model.visibleCurrentID },
            set: { id in
                guard let id, model.toc.indices.contains(id) else { return }
                if model.toc[id].hasChildren { model.expanded.insert(id) }
                model.goTo(model.toc[id])
                model.showsTOC = false
            }
        )
    }

    // 打开侧栏时展开到当前章节，并滚过去
    private func reveal(_ proxy: ScrollViewProxy) {
        guard model.showsTOC else { return }
        model.revealCurrent()
        if let id = model.currentID {
            DispatchQueue.main.async { proxy.scrollTo(id, anchor: .center) }
        }
    }
}

/// 红绿灯与工具栏只在需要时出现：目录或 Aa 面板打开、或鼠标停在窗口顶部。
/// 垫在整个窗口背后，用追踪区感知鼠标（不参与点击），淡入淡出整条标题栏。
struct WindowChrome: NSViewRepresentable {
    let visible: Bool
    /// 书名：标题栏隐藏着，但窗口菜单、调度中心、⌘` 用它；没有书名时保留文件名
    let title: String
    let onHoverTop: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView { TrackingView() }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onHoverTop = onHoverTop
        view.setChromeVisible(visible)
        if !title.isEmpty, let window = view.window, window.title != title { window.title = title }
    }

    final class TrackingView: NSView {
        var onHoverTop: (Bool) -> Void = { _ in }
        private var visible = true
        private static let band: CGFloat = 60 // 比带工具栏的标题栏（52pt）略高，按钮出现前鼠标已在区内

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // 书名改在侧栏头部，窗口菜单里仍是文件名。不用 .toolbar(removing: .title)：那样 Aa 会挤到左边
            window?.titleVisibility = .hidden
            applyAlpha(animated: false)
            rememberFrame()
        }

        // MARK: 窗口位置与大小
        // 全局只记一份「上次书窗口」，新书照它开，不按书记。不用 setFrameAutosaveName：同名只能给一个窗口用

        private static let frameKey = "bookWindowFrame"
        private var tracksFrame = false

        private func rememberFrame() {
            guard window != nil, !tracksFrame else { return }
            tracksFrame = true
            // 先同步读出旧值：SwiftUI 摆放窗口时会触发 didMove，先注册监听就会把默认尺寸存回去
            let saved = UserDefaults.standard.string(forKey: Self.frameKey).map(NSRectFromString)
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                if let saved, saved.width >= 300, saved.height >= 300 { Self.apply(saved, to: window) }
                let center = NotificationCenter.default
                center.addObserver(self, selector: #selector(self.frameChanged), name: NSWindow.didEndLiveResizeNotification, object: window)
                center.addObserver(self, selector: #selector(self.frameChanged), name: NSWindow.didMoveNotification, object: window)
                // 缩放按钮、辅助功能改尺寸不走 live resize，只发 didResize
                center.addObserver(self, selector: #selector(self.frameChanged), name: NSWindow.didResizeNotification, object: window)
            }
        }

        private static func apply(_ saved: NSRect, to window: NSWindow) {
            let others = NSApp.windows.filter { $0 !== window && $0.isVisible && $0.windowController?.document != nil }
            let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(saved) }
            if others.isEmpty && onScreen {
                window.setFrame(saved, display: true)
            } else {
                // 已有书窗口（系统会错开摆放）或屏幕变了：只沿用大小，左上角不动
                let top = window.frame.maxY
                window.setFrame(NSRect(x: window.frame.minX, y: top - saved.height, width: saved.width, height: saved.height), display: true)
                if !onScreen && others.isEmpty { window.center() }
            }
        }

        @objc private func frameChanged(_ note: Notification) {
            guard let window, !window.styleMask.contains(.fullScreen), !window.inLiveResize else { return }
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.frameKey)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            ))
        }

        override func mouseMoved(with event: NSEvent) { report(event) }
        override func mouseEntered(with event: NSEvent) { report(event) }
        override func mouseExited(with event: NSEvent) { onHoverTop(false) }

        private func report(_ event: NSEvent) {
            guard let window else { return }
            onHoverTop(window.frame.height - event.locationInWindow.y < Self.band)
        }

        func setChromeVisible(_ newValue: Bool) {
            guard newValue != visible else { return }
            visible = newValue
            applyAlpha(animated: true)
        }

        private func applyAlpha(animated: Bool) {
            // 全屏时标题栏由系统自己收放，不插手
            guard let window, !window.styleMask.contains(.fullScreen),
                  let titlebar = window.standardWindowButton(.closeButton)?.superview?.superview else { return }
            let alpha: CGFloat = visible ? 1 : 0
            if animated {
                NSAnimationContext.runAnimationGroup { $0.duration = 0.2; titlebar.animator().alphaValue = alpha }
            } else {
                titlebar.alphaValue = alpha
            }
        }
    }
}

struct ReaderCommands: Commands {
    @FocusedValue(\.reader) private var reader

    var body: some Commands {
        // 侧栏只有目录这一种用途，不再挂系统的「显示边栏」，免得两个菜单项管同一件事
        CommandGroup(before: .toolbar) {
            Button(reader?.showsTOC == true && reader?.panelTab == .toc ? "Hide Contents" : "Show Contents") {
                reader?.toggleTOC()
            }
            .keyboardShortcut("t")
            .disabled(reader == nil)
        }
        // 跳转（目录、书内链接、脚注「前往」）之后回到原处；快捷键与 Safari、Books 一致
        CommandMenu("Go") {
            Button("Location…") { reader?.goToPrompt() }
                .keyboardShortcut("l")
                .disabled(reader == nil)
            Divider()
            Button("Back") { reader?.goBack() }
                .keyboardShortcut("[")
                .disabled(reader?.canGoBack != true)
            Button("Forward") { reader?.goForward() }
                .keyboardShortcut("]")
                .disabled(reader?.canGoForward != true)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { reader?.find() }
                .keyboardShortcut("f")
                .disabled(reader == nil)
            Button("Find Next") { reader?.findNext() }
                .keyboardShortcut("g")
                .disabled(reader == nil)
            Button("Find Previous") { reader?.findPrevious() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(reader == nil)
        }
        CommandGroup(after: .toolbar) {
            // PDF 窗口缩放页面，其余调全局字号
            Button("Zoom In") { reader?.zoomIn() ?? ReaderSettings.shared.zoomIn() }
                .keyboardShortcut("=") // 实际按键 ⌘=，与 Safari 等一致
                .disabled(!(reader?.canZoomIn ?? ReaderSettings.shared.canZoomIn))
            Button("Zoom Out") { reader?.zoomOut() ?? ReaderSettings.shared.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!(reader?.canZoomOut ?? ReaderSettings.shared.canZoomOut))
            Button("Actual Size") { reader?.resetZoom() ?? ReaderSettings.shared.resetZoom() }
                .keyboardShortcut("0")
        }
    }
}

/// NSSearchField 包一层：SwiftUI 在 macOS 上没有独立的搜索框控件
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.stringValue = text
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        init(parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                if parent.text.isEmpty { parent.onCancel(); return true }
                return false // 交给搜索框自己清空
            default:
                return false
            }
        }
    }
}
