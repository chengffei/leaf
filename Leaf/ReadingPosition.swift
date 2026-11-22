import Foundation

/// 唯一持久化的状态：每本书读到哪（EPUB CFI，PDF 为 `pdf:<页码>`）。
enum ReadingPosition {
    private static let prefix = "position."
    private static func key(_ id: String) -> String { prefix + id }

    static func load(_ id: String) -> String? {
        UserDefaults.standard.string(forKey: key(id))
    }

    static func save(_ cfi: String, for id: String) {
        UserDefaults.standard.set(cfi, forKey: key(id))
    }

    private static var allKeys: [String] {
        UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
    }

    /// 记着位置的书有几本
    static var count: Int { allKeys.count }

    /// 设置里「清除阅读记录」：忘掉所有书的位置
    static func clearAll() {
        allKeys.forEach(UserDefaults.standard.removeObject(forKey:))
    }
}
