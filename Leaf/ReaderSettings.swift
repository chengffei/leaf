import Foundation
import Observation

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
    var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: "font") }
    }

    private init() {
        let zoom = defaults.integer(forKey: "zoomPercent")
        zoomPercent = Self.zoomRange.contains(zoom) ? zoom : 100
        lineSpacing = LineSpacing(rawValue: defaults.double(forKey: "lineSpacing")) ?? .standard
        font = ReaderFont(rawValue: defaults.string(forKey: "font") ?? "") ?? .original
    }

    var canZoomIn: Bool { zoomPercent < Self.zoomRange.upperBound }
    var canZoomOut: Bool { zoomPercent > Self.zoomRange.lowerBound }
    func zoomIn() { zoomPercent = min(zoomPercent + Self.zoomStep, Self.zoomRange.upperBound) }
    func zoomOut() { zoomPercent = max(zoomPercent - Self.zoomStep, Self.zoomRange.lowerBound) }
    func resetZoom() { zoomPercent = 100 }
}
