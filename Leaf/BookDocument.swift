import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mobi = UTType(importedAs: "com.chengffei.leaf.mobi")
    static let azw3 = UTType(importedAs: "com.chengffei.leaf.azw3")
    static let fb2 = UTType(importedAs: "com.chengffei.leaf.fb2")
    static let fbz = UTType(importedAs: "com.chengffei.leaf.fbz")
    static let cbz = UTType(importedAs: "com.chengffei.leaf.cbz")
    /// calibre、Kindle 登记的同名格式类型；装了它们，系统按扩展名认出来的是这些
    static let amazonTypes = ["com.amazon.mobi", "com.amazon.azw3", "com.amazon.azw"].compactMap { UTType($0) }
}

/// 只读文档：整本读进内存，交给 WebView 渲染。
struct BookDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.epub, .mobi, .azw3, .fb2, .fbz, .cbz, .pdf] + UTType.amazonTypes

    let data: Data
    /// 内容哈希：文件改名、挪位置后阅读进度仍然认得
    let id: String
    /// PDF 走原生 PDFKit，其余走 WebView
    let isPDF: Bool
    /// 文件名去掉扩展名：PDF 没有标题元数据时用它
    let title: String
    /// foliate 靠文件名认 FB2、FBZ、CBZ（CBZ 和 EPUB 都是 zip，FB2 没有魔数），其余格式为空
    let format: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        id = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        isPDF = configuration.contentType.conforms(to: .pdf)
        title = ((configuration.file.filename ?? "") as NSString).deletingPathExtension
        let type = configuration.contentType
        format = [(UTType.fb2, "fb2"), (.fbz, "fbz"), (.cbz, "cbz")].first { type.conforms(to: $0.0) }?.1 ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
