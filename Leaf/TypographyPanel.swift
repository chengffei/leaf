import SwiftUI

/// 工具栏 Aa 弹层：只放最常碰的字号与主题，其余在「设置…」
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

            VStack(alignment: .leading, spacing: 6) {
                Text("排版预设").font(.caption).foregroundStyle(.secondary)
                PresetPicker(settings: settings).labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("主题").font(.caption).foregroundStyle(.secondary)
                Picker("主题", selection: $settings.theme) {
                    ForEach(Theme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            SettingsLink {
                Text("更多设置…")
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 340) // 四段中文主题分段控件不会缩，窄了会从左边裁掉
    }
}
