import SwiftUI

/// 「Leaf › 设置… ⌘,」：全部阅读偏好，改动即时生效
struct SettingsView: View {
    @Bindable var settings = ReaderSettings.shared

    var body: some View {
        Form {
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
                segmented("行距", $settings.lineSpacing, LineSpacing.allCases)
            }
            Section("版式") {
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
    }

    private func segmented<T: Hashable & Identifiable>(_ title: String, _ selection: Binding<T>, _ cases: [T]) -> some View
        where T: LabeledCase {
        Picker(title, selection: selection) {
            ForEach(cases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

protocol LabeledCase { var label: String { get } }
extension LineSpacing: LabeledCase {}
extension PageMargin: LabeledCase {}
extension TextWidth: LabeledCase {}
extension Columns: LabeledCase {}
extension Theme: LabeledCase {}
