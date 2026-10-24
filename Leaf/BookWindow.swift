import SwiftUI

struct BookWindow: View {
    let book: BookDocument
    @State private var model = ReaderModel()
    @Environment(\.openSettings) private var openSettings
    private let settings = ReaderSettings.shared

    var body: some View {
        // 目录是浮动面板，盖在正文上：推挤式侧栏会让书重新分页，读者刚看到的那页就变了
        ZStack(alignment: .topLeading) {
            ReaderView(book: book, model: model, prefs: settings.prefs)
                // 铺到窗口顶部（标题文字已移除，按钮悬停才浮现）
                .ignoresSafeArea(.container, edges: .top)
            if model.showsTOC {
                TOCPanel(model: model)
                    .id("panel")
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showsTOC)
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
                    // 该符号随系统语言本地化（中文显示「大小」），固定用英文变体「Aa」
                    Image(systemName: "textformat.size")
                        .environment(\.locale, Locale(identifier: "en"))
                }
                .help("Size and Theme")
                .popover(isPresented: $model.showsTypography, arrowEdge: .bottom) {
                    TypographyPanel()
                }
            }
        }
        .background(
            WindowChrome(visible: model.showsTOC || model.hoversTop || model.showsTypography) { hovering in
                if model.hoversTop != hovering { model.hoversTop = hovering }
            }
            .ignoresSafeArea()
        )
        .focusedSceneValue(\.reader, model)
        .onAppear { model.openSettings = { openSettings() } }
        // 主题的浅色 / 深色：改窗口外观，WebView 的 prefers-color-scheme 跟着窗口走；米黄按浅色
        .preferredColorScheme(settings.theme.colorScheme)
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
    @FocusState private var focused: Bool
    @State private var debounce: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TextField("Find", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { text == model.searchQuery ? model.findNext() : model.search(text) }
                    .onExitCommand { model.showsTOC = false }
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
                    ForEach(groups, id: \.label) { group in
                        Section(group.label) {
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
        .onAppear { text = model.searchQuery; focused = true }
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
        case "done": model.searchHits.isEmpty ? "" : "\(model.searchIndex + 1) / \(model.searchHits.count)"
        default: ""
        }
    }

    private struct Group { let label: String; var hits: [SearchHit] }
    private var groups: [Group] {
        var out: [Group] = []
        for hit in model.searchHits {
            if out.last?.label == hit.label { out[out.count - 1].hits.append(hit) }
            else { out.append(Group(label: hit.label.isEmpty ? String(localized: "Body") : hit.label, hits: [hit])) }
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
    let onHoverTop: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView { TrackingView() }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onHoverTop = onHoverTop
        view.setChromeVisible(visible)
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
            let settings = ReaderSettings.shared
            Button("Zoom In") { settings.zoomIn() }
                .keyboardShortcut("=") // 实际按键 ⌘=，与 Safari 等一致
                .disabled(!settings.canZoomIn)
            Button("Zoom Out") { settings.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!settings.canZoomOut)
            Button("Actual Size") { settings.resetZoom() }
                .keyboardShortcut("0")
        }
    }
}
