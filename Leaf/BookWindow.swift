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
            // 不延伸进标题栏：书页自带背景（如白底封面）会铺到标题下，深色模式的浅色标题字被盖住
            .toolbar {
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
