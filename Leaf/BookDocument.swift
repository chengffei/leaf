import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mobi = UTType(importedAs: "com.chengffei.leaf.mobi")
    static let azw3 = UTType(importedAs: "com.chengffei.leaf.azw3")
}

/// 只读文档：整本读进内存，交给 WebView 渲染。
struct BookDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.epub, .mobi, .azw3]

    let data: Data
    /// 内容哈希：文件改名、挪位置后阅读进度仍然认得
    let id: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
