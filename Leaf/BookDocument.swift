import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mobi = UTType(importedAs: "com.chengffei.leaf.mobi")
    static let azw3 = UTType(importedAs: "com.chengffei.leaf.azw3")
    /// calibre、Kindle 登记的同名格式类型；装了它们，系统按扩展名认出来的是这些
    static let amazonTypes = ["com.amazon.mobi", "com.amazon.azw3", "com.amazon.azw"].compactMap { UTType($0) }
}

/// 只读文档：整本读进内存，交给 WebView 渲染。
struct BookDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.epub, .mobi, .azw3, .pdf] + UTType.amazonTypes

    let data: Data
    /// 内容哈希：文件改名、挪位置后阅读进度仍然认得
    let id: String
    /// PDF 走原生 PDFKit，其余走 WebView
    let isPDF: Bool
    /// 文件名去掉扩展名：PDF 没有标题元数据时用它
    let title: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        isPDF = configuration.contentType.conforms(to: .pdf)
        title = ((configuration.file.filename ?? "") as NSString).deletingPathExtension
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
