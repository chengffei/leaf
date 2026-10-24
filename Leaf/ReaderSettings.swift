import AppKit
import Foundation
import Observation
import SwiftUI

enum LineSpacing: Double, CaseIterable, Identifiable {
    case compact = 1.4, standard = 1.7, loose = 2.0
    var id: Double { rawValue }
    var label: String {
        switch self {
        case .compact: "紧凑"
        case .standard: "标准"
        case .loose: "宽松"
        }
    }
}

/// 内置的三种字体选项；除此之外 `ReaderSettings.font` 还可以是任意已安装字体的家族名
enum ReaderFont: String, CaseIterable, Identifiable {
    case original, sans, serif
    var id: String { rawValue }
    var label: String {
        switch self {
        case .original: "原书"
        case .sans: "黑体"
        case .serif: "宋体"
        }
    }
}

/// 页边距：正文四周的留白，左右为主，上下按比例跟着变（具体数值在 app.js 的 MARGINS）
enum PageMargin: String, CaseIterable, Identifiable {
    case narrow, standard, wide
    var id: String { rawValue }
    var label: String {
        switch self {
        case .narrow: "窄"
        case .standard: "标准"
        case .wide: "宽"
        }
    }
}

/// 版心最大宽度：一栏文字最宽多少像素，窗口再宽也不拉长行；0 = 不限
enum TextWidth: Int, CaseIterable, Identifiable {
    case narrow = 560, standard = 680, wide = 840, unlimited = 0
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .narrow: "窄"
        case .standard: "标准"
        case .wide: "宽"
        case .unlimited: "不限"
        }
    }
}

/// 分栏：自动 = 窗口够宽才两栏（foliate 默认）；单栏、双栏强制
enum Columns: String, CaseIterable, Identifiable {
    case auto, single, double
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "自动"
        case .single: "单栏"
        case .double: "双栏"
        }
    }
}

/// 主题：浅色 / 深色靠窗口外观（WebView 的 prefers-color-scheme 跟着窗口走），米黄在此之上再染色
enum Theme: String, CaseIterable, Identifiable {
    case system, light, sepia, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "纸白"
        case .sepia: "米黄"
        case .dark: "深色"
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
    }

    var prefs: ReaderPrefs {
        ReaderPrefs(
            fontScale: Double(zoomPercent) / 100, lineHeight: lineSpacing.rawValue, font: font,
            margin: margin.rawValue, maxWidth: textWidth.rawValue, columns: columns.rawValue, theme: theme.rawValue
        )
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
