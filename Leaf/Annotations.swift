import Foundation

/// 高亮、笔记与书签。按书的内容哈希存一份 JSON 在 Application Support，书文件一个字节不动；
/// 设置里可以一键全删，导出走系统存储面板
struct Annotation: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case highlight, bookmark }

    var id: UUID = UUID()
    var kind: Kind
    /// EPUB CFI：高亮是选区范围，书签是当页起点
    var cfi: String
    /// 高亮的原文；书签存当页开头几十个字，列表里好认
    var text: String
    var note: String = ""
    /// 高亮颜色名：yellow / green / blue / pink
    var color: String = "yellow"
    /// 所在章节名，列表按它分组
    var chapter: String = ""
    /// Kindle 式位置号，导出 My Clippings 用；没有就 0
    var location: Int = 0
    var created: Date = Date()
}

enum AnnotationStore {
    static let colors = ["yellow", "green", "blue", "pink"]

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Leaf/Annotations", isDirectory: true)
    }

    private static func file(_ bookID: String) -> URL { directory.appendingPathComponent("\(bookID).json") }

    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()

    static func load(_ bookID: String) -> [Annotation] {
        guard let data = try? Data(contentsOf: file(bookID)) else { return [] }
        return (try? decoder.decode([Annotation].self, from: data)) ?? []
    }

    /// 空列表就删文件，不留空壳
    static func save(_ items: [Annotation], for bookID: String) {
        let url = file(bookID)
        if items.isEmpty { try? FileManager.default.removeItem(at: url); return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? encoder.encode(items) { try? data.write(to: url, options: .atomic) }
    }

    /// 有标注的书有几本
    static var bookCount: Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).filter { $0.hasSuffix(".json") }.count
    }

    static func deleteAll() { try? FileManager.default.removeItem(at: directory) }
}

// MARK: - 导出

enum AnnotationExport {
    /// Markdown：书名、作者，按章节分节，高亮引用块，笔记跟在后面
    static func markdown(_ items: [Annotation], title: String, author: String) -> String {
        var out = "# \(title)\n"
        if !author.isEmpty { out += "\n\(author)\n" }
        var chapter: String? = nil
        for a in items {
            if a.chapter != chapter {
                chapter = a.chapter
                out += "\n## \(a.chapter.isEmpty ? String(localized: "Body") : a.chapter)\n"
            }
            out += "\n"
            switch a.kind {
            case .highlight:
                out += a.text.split(separator: "\n").map { "> \($0)" }.joined(separator: "\n") + "\n"
                if !a.note.isEmpty { out += "\n\(a.note)\n" }
            case .bookmark:
                out += "- \(String(localized: "Bookmark")): \(a.text)\n"
            }
        }
        return out
    }

    /// Kindle 的 My Clippings.txt：Readwise、Obsidian 的 Kindle 插件、Clippings.io 都按这个格式解析。
    /// 日期用英文格式，和 Kindle 一致；笔记单独成一条，紧跟在高亮后面
    static func clippings(_ items: [Annotation], title: String, author: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy h:mm:ss a"
        let head = author.isEmpty ? title : "\(title) (\(author))"
        // Kindle 的原文件带 BOM、用 CRLF；解析器大多按它写的，照抄最稳
        var out = "\u{FEFF}"
        func entry(_ kind: String, _ a: Annotation, _ body: String) {
            let location = a.location > 0 ? "Location \(a.location)" : "Location 1"
            out += "\(head)\r\n- Your \(kind) on \(location) | Added on \(formatter.string(from: a.created))\r\n\r\n\(body)\r\n==========\r\n"
        }
        for a in items {
            switch a.kind {
            case .highlight:
                entry("Highlight", a, a.text)
                if !a.note.isEmpty { entry("Note", a, a.note) }
            case .bookmark:
                entry("Bookmark", a, "")
            }
        }
        return out
    }
}
