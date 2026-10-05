import SwiftUI

struct BookWindow: View {
    let book: BookDocument
    @State private var model = ReaderModel()
    @State private var showsTypography = false
    private let settings = ReaderSettings.shared

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            TOCSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 380)
        } detail: {
            ReaderView(
                book: book, model: model,
                zoom: Double(settings.zoomPercent) / 100,
                lineSpacing: settings.lineSpacing, font: settings.font
            )
            // 铺到窗口顶部（标题文字已移除，按钮悬停才浮现）；左侧要给浮动侧栏让位，否则正文被侧栏盖住
            .ignoresSafeArea(.container, edges: .top)
            .toolbar {
                // 标题隐藏后工具栏会向左收拢，用弹性间隔把 Aa 推回右上角
                if #available(macOS 26.0, *) { ToolbarSpacer(.flexible) }
                ToolbarItem(placement: .primaryAction) {
                    Button { showsTypography.toggle() } label: {
                        // 该符号随系统语言本地化（中文显示「大小」），固定用英文变体「Aa」
                        Image(systemName: "textformat.size")
                            .environment(\.locale, Locale(identifier: "en"))
                    }
                    .help("字体与行距")
                    .popover(isPresented: $showsTypography, arrowEdge: .bottom) {
                        TypographyPanel()
                    }
                }
            }
        }
        .background(
            WindowChrome(visible: model.showsTOC || model.hoversTop || showsTypography) { hovering in
                if model.hoversTop != hovering { model.hoversTop = hovering }
            }
            .ignoresSafeArea()
        )
        .focusedSceneValue(\.reader, model)
    }

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { model.showsTOC ? .all : .detailOnly },
            set: { model.showsTOC = $0 != .detailOnly }
        )
    }
}

struct TOCSidebar: View {
    let model: ReaderModel

    var body: some View {
        Group {
            if model.toc.isEmpty {
                ContentUnavailableView("没有目录", systemImage: "list.bullet")
            } else {
                ScrollViewReader { proxy in
                    List(model.toc, selection: selection) { entry in
                        Text(entry.label)
                            .lineLimit(2)
                            .padding(.leading, CGFloat(entry.depth) * 14)
                            .help(entry.label)
                    }
                    .listStyle(.sidebar)
                    .onAppear { scrollToCurrent(proxy) }
                    .onChange(of: model.showsTOC) { scrollToCurrent(proxy) }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
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
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
    }

    // 读取 = 当前章节（随翻页高亮）；写入 = 用户点了某条 → 跳转
    private var selection: Binding<TOCEntry.ID?> {
        Binding(
            get: { model.currentID },
            set: { id in
                if let id, model.toc.indices.contains(id) { model.goTo(model.toc[id]) }
            }
        )
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        if model.showsTOC, let id = model.currentID { proxy.scrollTo(id, anchor: .center) }
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
            Button(reader?.showsTOC == true ? "隐藏目录" : "显示目录") {
                reader?.showsTOC.toggle()
            }
            .keyboardShortcut("t")
            .disabled(reader == nil)
        }
        // 跳转（目录、书内链接、脚注「前往」）之后回到原处；快捷键与 Safari、Books 一致
        CommandMenu("前往") {
            Button("返回") { reader?.goBack() }
                .keyboardShortcut("[")
                .disabled(reader?.canGoBack != true)
            Button("前进") { reader?.goForward() }
                .keyboardShortcut("]")
                .disabled(reader?.canGoForward != true)
        }
        CommandGroup(after: .toolbar) {
            let settings = ReaderSettings.shared
            Button("放大") { settings.zoomIn() }
                .keyboardShortcut("=") // 实际按键 ⌘=，与 Safari 等一致
                .disabled(!settings.canZoomIn)
            Button("缩小") { settings.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!settings.canZoomOut)
            Button("实际大小") { settings.resetZoom() }
                .keyboardShortcut("0")
        }
    }
}
