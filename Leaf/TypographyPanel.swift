import SwiftUI

/// 工具栏 Aa 弹层：只放最常碰的字号、主题、预设，其余在「设置…」
struct TypographyPanel: View {
    @Bindable var settings = ReaderSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SizeStepper(settings: settings)

            HStack(spacing: 0) {
                ForEach(Theme.allCases) { theme in
                    ThemeSwatch(theme: theme, selected: settings.theme == theme) { settings.theme = theme }
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 0) {
                Divider()
                HStack {
                    Text("Layout Preset")
                    Spacer()
                    PresetPicker(settings: settings)
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .buttonStyle(.borderless)
                        .fixedSize()
                }
                .frame(height: 36)
                Divider()
                SettingsLink {
                    HStack {
                        Text("More Settings…")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .frame(height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .frame(width: 320)
    }
}

/// 字号：一条胶囊里放「小 A ｜ 百分比 ｜ 大 A」，百分比点一下复位
struct SizeStepper: View {
    @Bindable var settings: ReaderSettings

    var body: some View {
        HStack(spacing: 0) {
            step(size: 13, enabled: settings.canZoomOut, label: "Zoom Out", help: "Smaller ⌘-") { settings.zoomOut() }
            Divider().frame(height: 18)
            Button { settings.resetZoom() } label: {
                Text("\(settings.zoomPercent)%")
                    .font(.callout).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reset ⌘0")
            .accessibilityLabel("Actual Size")
            .accessibilityValue("\(settings.zoomPercent)%")
            Divider().frame(height: 18)
            step(size: 20, enabled: settings.canZoomIn, label: "Zoom In", help: "Larger ⌘=") { settings.zoomIn() }
        }
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func step(size: CGFloat, enabled: Bool, label: LocalizedStringKey, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: "A")
                .font(.system(size: size, design: .serif))
                .foregroundStyle(enabled ? .primary : .tertiary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(label)
    }
}

/// 主题色样：圆里用该主题的底色和字色写 Aa，跟随系统画成浅深各半
struct ThemeSwatch: View {
    let theme: Theme
    let selected: Bool
    let action: () -> Void

    private static let paper = (Color(hex: 0xFBFAF7), Color(hex: 0x1D1D1F))
    private static let dark = (Color(hex: 0x1C1C1E), Color(hex: 0xE5E5E7))

    private var colors: (bg: Color, fg: Color) {
        switch theme {
        case .system, .light: Self.paper
        case .sepia: (Color(hex: 0xF4ECD8), Color(hex: 0x5B4636))
        case .eink: (Color(hex: 0xECEAE4), Color(hex: 0x1F1F1F))
        case .dark: Self.dark
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(colors.bg)
                    if theme == .system {
                        // 右下半边画深色
                        Circle().fill(Self.dark.0).mask(
                            Rectangle().rotationEffect(.degrees(45)).offset(x: 20, y: 20)
                        )
                    }
                    Text(verbatim: "Aa")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(theme == .system ? Color.gray : colors.fg)
                }
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))

                Text(theme.label)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(theme.label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
