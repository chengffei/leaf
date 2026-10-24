import SwiftUI

/// 「Leaf › 设置… ⌘,」：全部阅读偏好，改动即时生效
struct SettingsView: View {
    @Bindable var settings = ReaderSettings.shared
    @State private var namingPreset = false
    @State private var presetName = ""

    var body: some View {
        Form {
            Section("预设") {
                PresetPicker(settings: settings)
                HStack {
                    Button("把当前设置存为预设…") { presetName = ""; namingPreset = true }
                    Spacer()
                }
                ForEach(settings.customPresets) { preset in
                    LabeledContent(preset.name) {
                        Button("删除") { settings.deletePreset(preset) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("文字") {
                Picker("字体", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text($0.label).tag($0.rawValue) }
                    Divider()
                    ForEach(ReaderSettings.installedFonts, id: \.family) { font in
                        Text(font.display).tag(font.family)
                    }
                }
                LabeledContent("字号") {
                    HStack(spacing: 8) {
                        Text("\(settings.zoomPercent)%").monospacedDigit()
                        Stepper("字号", value: $settings.zoomPercent, in: ReaderSettings.zoomRange, step: ReaderSettings.zoomStep)
                            .labelsHidden()
                    }
                }
                LabeledContent("字重") {
                    HStack(spacing: 8) {
                        Text(settings.weight == 0 ? "原书" : "+\(settings.weight)").monospacedDigit()
                        Stepper("字重", value: $settings.weight, in: ReaderSettings.weightRange).labelsHidden()
                    }
                }
                segmented("行距", $settings.lineSpacing, LineSpacing.allCases)
                segmented("段距", $settings.paragraphSpacing, ParagraphSpacing.allCases)
                segmented("字距", $settings.letterSpacing, LetterSpacing.allCases)
            }
            Section("版式") {
                segmented("对齐", $settings.align, TextAlign.allCases)
                segmented("页边距", $settings.margin, PageMargin.allCases)
                segmented("版心宽度", $settings.textWidth, TextWidth.allCases)
                segmented("分栏", $settings.columns, Columns.allCases)
            }
            Section("外观") {
                segmented("主题", $settings.theme, Theme.allCases)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .alert("预设名称", isPresented: $namingPreset) {
            TextField("名称", text: $presetName)
            Button("保存") { settings.savePreset(named: presetName) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("保存字体、字号、字重、间距、页边距、版心、分栏和对齐；主题另算。")
        }
    }

    private func segmented<T: Hashable & Identifiable>(_ title: String, _ selection: Binding<T>, _ cases: [T]) -> some View
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
        Picker("排版预设", selection: selection) {
            Text("自定义").tag("")
            ForEach(Preset.builtins) { Text($0.name).tag($0.name) }
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
