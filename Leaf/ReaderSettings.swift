import AppKit
import Foundation
import Observation
import SwiftUI

enum LineSpacing: Double, CaseIterable, Identifiable, Codable {
    case compact = 1.4, standard = 1.7, loose = 2.0
    var id: Double { rawValue }
    var label: String {
        switch self {
        case .compact: String(localized: "Compact")
        case .standard: String(localized: "Standard")
        case .loose: String(localized: "Loose")
        }
    }
}

/// 内置的三种字体选项；除此之外 `ReaderSettings.font` 还可以是任意已安装字体的家族名
enum ReaderFont: String, CaseIterable, Identifiable {
    case original, sans, serif
    var id: String { rawValue }
    var label: String {
        switch self {
        case .original: String(localized: "Original")
        case .sans: String(localized: "Sans-serif")
        case .serif: String(localized: "Serif")
        }
    }
}

/// 页边距：正文四周的留白，左右为主，上下按比例跟着变（具体数值在 app.js 的 MARGINS）
enum PageMargin: String, CaseIterable, Identifiable, Codable {
    case narrow, standard, wide
    var id: String { rawValue }
    var label: String {
        switch self {
        case .narrow: String(localized: "Narrow")
        case .standard: String(localized: "Standard")
        case .wide: String(localized: "Wide")
        }
    }
}

/// 版心最大宽度：一栏文字最宽多少像素，窗口再宽也不拉长行；0 = 不限
enum TextWidth: Int, CaseIterable, Identifiable, Codable {
    case narrow = 560, standard = 680, wide = 840, unlimited = 0
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .narrow: String(localized: "Narrow")
        case .standard: String(localized: "Standard")
        case .wide: String(localized: "Wide")
        case .unlimited: String(localized: "Unlimited")
        }
    }
}

/// 分栏：自动 = 窗口够宽才两栏（foliate 默认）；单栏、双栏强制
enum Columns: String, CaseIterable, Identifiable, Codable {
    case auto, single, double
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .single: String(localized: "One column")
        case .double: String(localized: "Two columns")
        }
    }
}

/// 对齐：两端（默认，书多半也这么排）或左对齐
enum TextAlign: String, CaseIterable, Identifiable, Codable {
    case justify, left
    var id: String { rawValue }
    var label: String {
        switch self {
        case .justify: String(localized: "Justified")
        case .left: String(localized: "Left")
        }
    }
}

/// 段距：原书不动，紧凑 / 宽松强制覆盖
enum ParagraphSpacing: String, CaseIterable, Identifiable, Codable {
    case tight, original, loose
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tight: String(localized: "Compact")
        case .original: String(localized: "Original")
        case .loose: String(localized: "Loose")
        }
    }
}

/// 字距
enum LetterSpacing: String, CaseIterable, Identifiable, Codable {
    case tight, standard, loose
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tight: String(localized: "Tight")
        case .standard: String(localized: "Standard")
        case .loose: String(localized: "Loose")
        }
    }
}

/// 主题：浅色 / 深色靠窗口外观（WebView 的 prefers-color-scheme 跟着窗口走），米黄在此之上再染色
enum Theme: String, CaseIterable, Identifiable {
    case system, light, sepia, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Paper")
        case .sepia: String(localized: "Sepia")
        case .dark: String(localized: "Dark")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }
}

/// 推给页面的全部排版参数；字段名与 app.js 的 prefs 一致
struct ReaderPrefs: Equatable, Encodable {
    let fontScale: Double
    let lineHeight: Double
    let font: String
    let margin: String
    let maxWidth: Int
    let columns: String
    let theme: String
    let weight: Int
    let align: String
    let paragraphSpacing: String
    let letterSpacing: String
    /// 界面语言，网页层据此选文案；取 app 实际用的本地化，不是系统首选
    let lang: String

    var json: String {
        String(data: (try? JSONEncoder().encode(self)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"
    }
}

/// 全局排版设置：所有书共用，改动即时推到每个打开的窗口。
@MainActor @Observable
final class ReaderSettings {
    static let shared = ReaderSettings()
    static let zoomRange = 80...200
    static let zoomStep = 10

    private let defaults = UserDefaults.standard

    /// 字号百分比：在书页里放大根字号（作用于 em/rem/% 字号）。
    /// 不用 WKWebView.pageZoom —— 非 100% 时 foliate 分页按缩放前后混合的尺寸计算，分栏会错位。
    var zoomPercent: Int {
        didSet { defaults.set(zoomPercent, forKey: "zoomPercent") }
    }
    var lineSpacing: LineSpacing {
        didSet { defaults.set(lineSpacing.rawValue, forKey: "lineSpacing") }
    }
    /// `ReaderFont` 的 rawValue，或任意已安装字体的家族名（如 "LXGW WenKai"）
    var font: String {
        didSet { defaults.set(font, forKey: "font") }
    }
    var margin: PageMargin {
        didSet { defaults.set(margin.rawValue, forKey: "margin") }
    }
    var textWidth: TextWidth {
        didSet { defaults.set(textWidth.rawValue, forKey: "textWidth") }
    }
    var columns: Columns {
        didSet { defaults.set(columns.rawValue, forKey: "columns") }
    }
    var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: "theme") }
    }
    /// 字重 0 到 4：0 = 原书，其余按描边加粗（任何字体都生效，不依赖可变字体）
    var weight: Int {
        didSet { defaults.set(weight, forKey: "weight") }
    }
    var align: TextAlign {
        didSet { defaults.set(align.rawValue, forKey: "align") }
    }
    var paragraphSpacing: ParagraphSpacing {
        didSet { defaults.set(paragraphSpacing.rawValue, forKey: "paragraphSpacing") }
    }
    var letterSpacing: LetterSpacing {
        didSet { defaults.set(letterSpacing.rawValue, forKey: "letterSpacing") }
    }
    /// 自定义排版预设，内置四套在 `Preset.builtins`
    var customPresets: [Preset] {
        didSet { defaults.set(try? JSONEncoder().encode(customPresets), forKey: "presets") }
    }
    static let weightRange = 0...4
    /// 界面语言："" = 跟随系统，否则是 lproj 代码。写进 AppleLanguages，下次启动生效（菜单栏由 AppKit 在启动时定，改不了）
    var uiLanguage: String {
        didSet {
            defaults.set(uiLanguage, forKey: "uiLanguage")
            if uiLanguage.isEmpty { defaults.removeObject(forKey: "AppleLanguages") }
            else { defaults.set([uiLanguage], forKey: "AppleLanguages") }
        }
    }
    /// 可选语言与各自的母语名；顺序 = 设置里的顺序
    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"),
        ("ko", "한국어"), ("fr", "Français"), ("de", "Deutsch"), ("es", "Español"),
    ]

    private init() {
        let zoom = defaults.integer(forKey: "zoomPercent")
        zoomPercent = Self.zoomRange.contains(zoom) ? zoom : 100
        lineSpacing = LineSpacing(rawValue: defaults.double(forKey: "lineSpacing")) ?? .standard
        font = defaults.string(forKey: "font") ?? ReaderFont.original.rawValue
        margin = PageMargin(rawValue: defaults.string(forKey: "margin") ?? "") ?? .standard
        // 用 integer(forKey:) 读：命令行参数（-textWidth 0）存的是字符串
        textWidth = defaults.object(forKey: "textWidth") == nil ? .standard
            : TextWidth(rawValue: defaults.integer(forKey: "textWidth")) ?? .standard
        columns = Columns(rawValue: defaults.string(forKey: "columns") ?? "") ?? .auto
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        let w = defaults.integer(forKey: "weight")
        weight = Self.weightRange.contains(w) ? w : 0
        align = TextAlign(rawValue: defaults.string(forKey: "align") ?? "") ?? .justify
        paragraphSpacing = ParagraphSpacing(rawValue: defaults.string(forKey: "paragraphSpacing") ?? "") ?? .original
        letterSpacing = LetterSpacing(rawValue: defaults.string(forKey: "letterSpacing") ?? "") ?? .standard
        customPresets = defaults.data(forKey: "presets").flatMap { try? JSONDecoder().decode([Preset].self, from: $0) } ?? []
        uiLanguage = defaults.string(forKey: "uiLanguage") ?? ""
    }

    /// 语言改了要重开才生效：开一个新实例带上当前打开的书，再退出自己
    func relaunch() {
        let files = NSDocumentController.shared.documents.compactMap(\.fileURL?.path)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-n", "-a", Bundle.main.bundlePath] + files
        try? p.run()
        NSApp.terminate(nil)
    }

    var prefs: ReaderPrefs {
        ReaderPrefs(
            fontScale: Double(zoomPercent) / 100, lineHeight: lineSpacing.rawValue, font: font,
            margin: margin.rawValue, maxWidth: textWidth.rawValue, columns: columns.rawValue, theme: theme.rawValue,
            weight: weight, align: align.rawValue, paragraphSpacing: paragraphSpacing.rawValue, letterSpacing: letterSpacing.rawValue,
            lang: Bundle.main.preferredLocalizations.first ?? "en"
        )
    }

    // MARK: 排版预设

    /// 当前设置抓成一份预设（不含主题：底色是另一回事，Kindle 也分开放）
    func snapshot(named name: String) -> Preset {
        Preset(
            name: name, font: font, zoomPercent: zoomPercent, weight: weight, lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing, letterSpacing: letterSpacing, margin: margin,
            textWidth: textWidth, columns: columns, align: align
        )
    }

    func apply(_ preset: Preset) {
        if let f = preset.font { font = f }
        zoomPercent = preset.zoomPercent
        weight = preset.weight
        lineSpacing = preset.lineSpacing
        paragraphSpacing = preset.paragraphSpacing
        letterSpacing = preset.letterSpacing
        margin = preset.margin
        textWidth = preset.textWidth
        columns = preset.columns
        align = preset.align
    }

    var allPresets: [Preset] { Preset.builtins + customPresets }

    /// 当前设置正好等于哪个预设；都不是就 nil（界面显示「自定义」）
    var currentPreset: Preset? {
        allPresets.first { $0.matches(self) }
    }

    func savePreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        customPresets.removeAll { $0.name == trimmed }
        customPresets.append(snapshot(named: trimmed))
    }

    func deletePreset(_ preset: Preset) {
        customPresets.removeAll { $0.name == preset.name }
    }

    var canZoomIn: Bool { zoomPercent < Self.zoomRange.upperBound }
    var canZoomOut: Bool { zoomPercent > Self.zoomRange.lowerBound }
    func zoomIn() { zoomPercent = min(zoomPercent + Self.zoomStep, Self.zoomRange.upperBound) }
    func zoomOut() { zoomPercent = max(zoomPercent - Self.zoomStep, Self.zoomRange.lowerBound) }
    func resetZoom() { zoomPercent = 100 }

    /// 已安装的字体家族（去掉以「.」开头的系统内部字体），显示名本地化，值是 CSS 认的家族名
    static let installedFonts: [(family: String, display: String)] = {
        let manager = NSFontManager.shared
        return manager.availableFontFamilies
            .filter { !$0.hasPrefix(".") }
            .map { ($0, manager.localizedName(forFamily: $0, face: nil)) }
            .sorted { $0.display.localizedStandardCompare($1.display) == .orderedAscending }
    }()

    /// 当前字体的显示名，给面板和菜单用
    var fontLabel: String {
        if let builtin = ReaderFont(rawValue: font) { return builtin.label }
        return Self.installedFonts.first { $0.family == font }?.display ?? font
    }
}

/// 一套排版：字体可选（内置预设不碰字体），其余都带
struct Preset: Codable, Identifiable, Hashable {
    var name: String
    var font: String?
    var zoomPercent: Int
    var weight: Int
    var lineSpacing: LineSpacing
    var paragraphSpacing: ParagraphSpacing
    var letterSpacing: LetterSpacing
    var margin: PageMargin
    var textWidth: TextWidth
    var columns: Columns
    var align: TextAlign

    var id: String { name }
    /// 内置预设的名字是英文 key，显示时翻译；自定义的照原样
    var displayName: String {
        Self.builtins.contains { $0.name == name } ? String(localized: String.LocalizationValue(name)) : name
    }

    @MainActor func matches(_ s: ReaderSettings) -> Bool {
        (font == nil || font == s.font) && zoomPercent == s.zoomPercent && weight == s.weight
            && lineSpacing == s.lineSpacing && paragraphSpacing == s.paragraphSpacing
            && letterSpacing == s.letterSpacing && margin == s.margin && textWidth == s.textWidth
            && columns == s.columns && align == s.align
    }

    /// 内置四套，对应 Kindle 的 Compact / Standard / Large / Low Vision
    static let builtins: [Preset] = [
        Preset(name: "Compact", font: nil, zoomPercent: 90, weight: 0, lineSpacing: .compact, paragraphSpacing: .tight,
               letterSpacing: .standard, margin: .narrow, textWidth: .wide, columns: .auto, align: .justify),
        Preset(name: "Standard", font: nil, zoomPercent: 100, weight: 0, lineSpacing: .standard, paragraphSpacing: .original,
               letterSpacing: .standard, margin: .standard, textWidth: .standard, columns: .auto, align: .justify),
        Preset(name: "Large", font: nil, zoomPercent: 130, weight: 1, lineSpacing: .loose, paragraphSpacing: .original,
               letterSpacing: .standard, margin: .standard, textWidth: .wide, columns: .auto, align: .justify),
        Preset(name: "Low Vision", font: nil, zoomPercent: 170, weight: 3, lineSpacing: .loose, paragraphSpacing: .loose,
               letterSpacing: .loose, margin: .narrow, textWidth: .unlimited, columns: .single, align: .left),
    ]
}
