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

    /// 字号百分比，用 WebView 的 pageZoom 实现，对写死像素字号的书也有效
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

    /// 传给 JS 的排版参数（字号走原生 pageZoom，不在这里）
    var webPrefs: [String: Any] { ["lineHeight": lineSpacing.rawValue, "font": font.rawValue] }
}
