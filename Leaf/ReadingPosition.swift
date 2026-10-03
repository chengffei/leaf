import Foundation

/// 唯一持久化的状态：每本书读到哪（EPUB CFI）。
enum ReadingPosition {
    private static func key(_ id: String) -> String { "position.\(id)" }

    static func load(_ id: String) -> String? {
        UserDefaults.standard.string(forKey: key(id))
    }

    static func save(_ cfi: String, for id: String) {
        UserDefaults.standard.set(cfi, forKey: key(id))
    }
}
