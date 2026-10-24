import SwiftUI

/// 「Leaf › 设置… ⌘,」：全部阅读偏好，改动即时生效
struct SettingsView: View {
    @Bindable var settings = ReaderSettings.shared
    @State private var namingPreset = false
    @State private var presetName = ""
    /// 启动时的语言设置；改了且没重开，就显示「重新打开」
    @State private var launchedLanguage = ReaderSettings.shared.uiLanguage

    var body: some View {
        Form {
            Section("Presets") {
                PresetPicker(settings: settings)
                HStack {
                    Button("Save Current Settings as Preset…") { presetName = ""; namingPreset = true }
                    Spacer()
                }
                ForEach(settings.customPresets) { preset in
                    LabeledContent(preset.displayName) {
                        Button("Delete") { settings.deletePreset(preset) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Text") {
                Picker("Font", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text($0.label).tag($0.rawValue) }
                    Divider()
                    ForEach(ReaderSettings.installedFonts, id: \.family) { font in
                        Text(font.display).tag(font.family)
                    }
                }
                LabeledContent("Size") {
                    HStack(spacing: 8) {
                        Text("\(settings.zoomPercent)%").monospacedDigit()
                        Stepper("Size", value: $settings.zoomPercent, in: ReaderSettings.zoomRange, step: ReaderSettings.zoomStep)
                            .labelsHidden()
                    }
                }
                LabeledContent("Weight") {
                    HStack(spacing: 8) {
                        Text(settings.weight == 0 ? String(localized: "Original") : "+\(settings.weight)").monospacedDigit()
                        Stepper("Weight", value: $settings.weight, in: ReaderSettings.weightRange).labelsHidden()
                    }
                }
                segmented("Line Spacing", $settings.lineSpacing, LineSpacing.allCases)
                segmented("Paragraph Spacing", $settings.paragraphSpacing, ParagraphSpacing.allCases)
                segmented("Letter Spacing", $settings.letterSpacing, LetterSpacing.allCases)
            }
            Section("Layout") {
                segmented("Alignment", $settings.align, TextAlign.allCases)
                segmented("Margins", $settings.margin, PageMargin.allCases)
                segmented("Text Width", $settings.textWidth, TextWidth.allCases)
                segmented("Columns", $settings.columns, Columns.allCases)
            }
            Section("Appearance") {
                segmented("Theme", $settings.theme, Theme.allCases)
            }
            Section("Language") {
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
        }
        .formStyle(.grouped)
        // 高度固定、内容滚动：按内容撑开会高过小屏，底部被 Dock 盖住
        .frame(width: 460, height: 720)
        .alert("Preset Name", isPresented: $namingPreset) {
            TextField("Name", text: $presetName)
            Button("Save") { settings.savePreset(named: presetName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves font, size, weight, spacing, margins, text width, columns and alignment. Theme is kept separate.")
        }
    }

    // 标题类型必须是 LocalizedStringKey，用 String 就不会查翻译表
    private func segmented<T: Hashable & Identifiable>(_ title: LocalizedStringKey, _ selection: Binding<T>, _ cases: [T]) -> some View
        where T: LabeledCase {
        Picker(title, selection: selection) {
            ForEach(cases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }
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
