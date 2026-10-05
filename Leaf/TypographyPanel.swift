import SwiftUI

struct TypographyPanel: View {
    @Bindable var settings = ReaderSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { settings.zoomOut() } label: {
                    Text("A").font(.system(size: 12))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .disabled(!settings.canZoomOut)
                .help("缩小 ⌘-")

                Button { settings.resetZoom() } label: {
                    Text("\(settings.zoomPercent)%").monospacedDigit()
                        .frame(width: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("恢复默认 ⌘0")

                Button { settings.zoomIn() } label: {
                    Text("A").font(.system(size: 18))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .disabled(!settings.canZoomIn)
                .help("放大 ⌘=")
            }

            row("行距") {
                Picker("行距", selection: $settings.lineSpacing) {
                    ForEach(LineSpacing.allCases) { Text($0.label).tag($0) }
                }
            }

            row("页边距") {
                Picker("页边距", selection: $settings.margin) {
                    ForEach(PageMargin.allCases) { Text($0.label).tag($0) }
                }
            }

            row("字体") {
                Picker("字体", selection: $settings.font) {
                    ForEach(ReaderFont.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            picker().pickerStyle(.segmented).labelsHidden()
        }
    }
}
