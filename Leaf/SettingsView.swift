import SwiftUI
import WebKit

/// 「Leaf › 设置… ⌘,」：全部阅读偏好，改动即时生效
/// 分两页：阅读（由整体到局部：预设 → 外观 → 文字 → 间距 → 版式）、通用（语言）
struct SettingsView: View {
    var body: some View {
        TabView {
            ReadingSettings()
                .tabItem { Label("Reading", systemImage: "book") }
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
    }
}

private struct ReadingSettings: View {
    @Bindable var settings = ReaderSettings.shared
    @State private var namingPreset = false
    @State private var presetName = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Layout Preset") {
                    HStack(spacing: 10) {
                        PresetPicker(settings: settings)
                            .labelsHidden()
                            .fixedSize()
                        Button("Save as Preset…") { presetName = ""; namingPreset = true }
                    }
                }
                ForEach(settings.customPresets) { preset in
                    LabeledContent(preset.displayName) {
                        Button("Delete") { settings.deletePreset(preset) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Appearance") {
                HStack(spacing: 0) {
                    ForEach(Theme.allCases) { theme in
                        ThemeSwatch(theme: theme, selected: settings.theme == theme) { settings.theme = theme }
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Text") {
                Picker("Font", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text($0.label).tag($0.rawValue) }
                    Divider()
                    ForEach(ReaderSettings.installedFonts, id: \.family) { font in
                        Text(font.display).tag(font.family)
                    }
                }
                // 不用 LabeledContent：控件比一行高时，它把标签顶到上沿
                HStack {
                    Text("Size")
                    Spacer()
                    SizeStepper(settings: settings).frame(width: 180)
                }
                LabeledContent("Weight") {
                    HStack(spacing: 8) {
                        Text(settings.weight == 0 ? String(localized: "Original") : "+\(settings.weight)")
                            .monospacedDigit().foregroundStyle(.secondary)
                        Stepper("Weight", value: $settings.weight, in: ReaderSettings.weightRange).labelsHidden()
                    }
                }
            }
            Section("Spacing") {
                menu("Line Spacing", $settings.lineSpacing, LineSpacing.allCases)
                menu("Paragraph Spacing", $settings.paragraphSpacing, ParagraphSpacing.allCases)
                menu("Letter Spacing", $settings.letterSpacing, LetterSpacing.allCases)
            }
            Section("Layout") {
                menu("Alignment", $settings.align, TextAlign.allCases)
                menu("Margins", $settings.margin, PageMargin.allCases)
                menu("Text Width", $settings.textWidth, TextWidth.allCases)
                menu("Columns", $settings.columns, Columns.allCases)
            }
        }
        .formStyle(.grouped)
        // 高度固定、内容滚动：按内容撑开会高过小屏，底部被 Dock 盖住
        .frame(width: 460, height: 640)
        .alert("Preset Name", isPresented: $namingPreset) {
            TextField("Name", text: $presetName)
            Button("Save") { settings.savePreset(named: presetName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves font, size, weight, spacing, margins, text width, columns and alignment. Theme is kept separate.")
        }
    }

    // 标题类型必须是 LocalizedStringKey，用 String 就不会查翻译表
    private func menu<T: Hashable & Identifiable>(_ title: LocalizedStringKey, _ selection: Binding<T>, _ cases: [T]) -> some View
        where T: LabeledCase {
        Picker(title, selection: selection) {
            ForEach(cases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
    }
}

private struct GeneralSettings: View {
    @Bindable var settings = ReaderSettings.shared
    /// 启动时的语言设置；改了且没重开，就显示「重新打开」
    @State private var launchedLanguage = ReaderSettings.shared.uiLanguage
    @State private var historyCount = ReadingPosition.count
    @State private var confirmsClear = false
    @State private var notesBooks = AnnotationStore.bookCount
    @State private var confirmsDeleteNotes = false

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $settings.uiLanguage) {
                    Text("Follow System").tag("")
                    Divider()
                    ForEach(ReaderSettings.languages, id: \.code) { Text($0.name).tag($0.code) }
                }
                if settings.uiLanguage != launchedLanguage {
                    LabeledContent {
                        Button("Reopen Now") { settings.relaunch() }
                    } label: {
                        Text("Takes effect the next time Leaf opens.").foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                LabeledContent {
                    Button("Clear…") { confirmsClear = true }
                        .disabled(historyCount == 0)
                } label: {
                    Text("Reading History")
                    if historyCount == 0 {
                        Text("No reading history.")
                    } else {
                        Text("Leaf remembers your place in \(historyCount) books.")
                    }
                }
                LabeledContent {
                    Button("Delete…") { confirmsDeleteNotes = true }
                        .disabled(notesBooks == 0)
                } label: {
                    Text("Notes and Highlights")
                    if notesBooks == 0 {
                        Text("No notes or highlights.")
                    } else {
                        Text("Notes and highlights in \(notesBooks) books. Export them from the Notes menu first.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 460, height: 250)
        .onAppear { historyCount = ReadingPosition.count; notesBooks = AnnotationStore.bookCount }
        .alert("Delete All Notes and Highlights?", isPresented: $confirmsDeleteNotes) {
            Button("Delete", role: .destructive) {
                AnnotationStore.deleteAll()
                notesBooks = 0
                NotificationCenter.default.post(name: .annotationsDeleted, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every highlight, note and bookmark in every book. It can’t be undone.")
        }
        .alert("Clear Reading History?", isPresented: $confirmsClear) {
            Button("Clear", role: .destructive) { clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Leaf will forget where you stopped in every book and how fast you read. Your books stay as they are.")
        }
    }

    /// 位置存在 UserDefaults，阅读速度存在网页的 localStorage。
    /// 先清 localStorage，再通知开着的书把内存里的速度也归零，否则下一次翻页会写回去
    private func clearHistory() {
        ReadingPosition.clearAll()
        historyCount = 0
        WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeLocalStorage], modifiedSince: .distantPast) {
            NotificationCenter.default.post(name: .readingHistoryCleared, object: nil)
        }
    }
}

extension Notification.Name {
    static let readingHistoryCleared = Notification.Name("LeafReadingHistoryCleared")
    static let annotationsDeleted = Notification.Name("LeafAnnotationsDeleted")
}

/// 预设下拉：内置四套在前，自定义在后；当前设置不等于任何预设时显示「自定义」
struct PresetPicker: View {
    @Bindable var settings: ReaderSettings

    var body: some View {
        Picker("Layout Preset", selection: selection) {
            Text("Custom").tag("")
            ForEach(Preset.builtins) { Text($0.displayName).tag($0.name) }
            if !settings.customPresets.isEmpty {
                Divider()
                ForEach(settings.customPresets) { Text($0.name).tag($0.name) }
            }
        }
    }

    private var selection: Binding<String> {
        Binding(
            get: { settings.currentPreset?.name ?? "" },
            set: { name in
                if let preset = settings.allPresets.first(where: { $0.name == name }) { settings.apply(preset) }
            }
        )
    }
}

protocol LabeledCase { var label: String { get } }
extension LineSpacing: LabeledCase {}
extension PageMargin: LabeledCase {}
extension TextWidth: LabeledCase {}
extension Columns: LabeledCase {}
extension Theme: LabeledCase {}
extension TextAlign: LabeledCase {}
extension ParagraphSpacing: LabeledCase {}
extension LetterSpacing: LabeledCase {}
