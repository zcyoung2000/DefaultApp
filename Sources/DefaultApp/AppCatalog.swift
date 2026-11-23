import AppKit
import UniformTypeIdentifiers

/// 内置的扩展名目录。UTType 没有公开的「列出全部类型」接口，
/// 因此这里维护一份常用清单，覆盖绝大多数日常场景。
enum AppCatalog {
    struct Entry {
        let fileExtension: String
        let category: FileType.Category
    }

    static let entries: [Entry] = [
        // 文档
        .init(fileExtension: "txt", category: .document),
        .init(fileExtension: "md", category: .document),
        .init(fileExtension: "rtf", category: .document),
        .init(fileExtension: "pdf", category: .document),
        .init(fileExtension: "doc", category: .document),
        .init(fileExtension: "docx", category: .document),
        .init(fileExtension: "xls", category: .document),
        .init(fileExtension: "xlsx", category: .document),
        .init(fileExtension: "ppt", category: .document),
        .init(fileExtension: "pptx", category: .document),
        .init(fileExtension: "csv", category: .document),
        .init(fileExtension: "pages", category: .document),
        .init(fileExtension: "numbers", category: .document),
        .init(fileExtension: "key", category: .document),
        .init(fileExtension: "epub", category: .document),
        // 图片
        .init(fileExtension: "png", category: .image),
        .init(fileExtension: "jpg", category: .image),
        .init(fileExtension: "jpeg", category: .image),
        .init(fileExtension: "gif", category: .image),
        .init(fileExtension: "webp", category: .image),
        .init(fileExtension: "heic", category: .image),
        .init(fileExtension: "tiff", category: .image),
        .init(fileExtension: "bmp", category: .image),
        .init(fileExtension: "svg", category: .image),
        .init(fileExtension: "ico", category: .image),
        .init(fileExtension: "psd", category: .image),
        .init(fileExtension: "ai", category: .image),
        // 音视频
        .init(fileExtension: "mp3", category: .media),
        .init(fileExtension: "wav", category: .media),
        .init(fileExtension: "flac", category: .media),
        .init(fileExtension: "aac", category: .media),
        .init(fileExtension: "m4a", category: .media),
        .init(fileExtension: "mp4", category: .media),
        .init(fileExtension: "mov", category: .media),
        .init(fileExtension: "mkv", category: .media),
        .init(fileExtension: "avi", category: .media),
        .init(fileExtension: "webm", category: .media),
        // 开发文件
        .init(fileExtension: "html", category: .code),
        .init(fileExtension: "css", category: .code),
        .init(fileExtension: "js", category: .code),
        .init(fileExtension: "ts", category: .code),
        .init(fileExtension: "json", category: .code),
        .init(fileExtension: "yaml", category: .code),
        .init(fileExtension: "yml", category: .code),
        .init(fileExtension: "xml", category: .code),
        .init(fileExtension: "java", category: .code),
        .init(fileExtension: "py", category: .code),
        .init(fileExtension: "go", category: .code),
        .init(fileExtension: "rs", category: .code),
        .init(fileExtension: "swift", category: .code),
        .init(fileExtension: "c", category: .code),
        .init(fileExtension: "cpp", category: .code),
        .init(fileExtension: "h", category: .code),
        .init(fileExtension: "sh", category: .code),
        .init(fileExtension: "sql", category: .code),
        .init(fileExtension: "toml", category: .code),
        // 压缩包
        .init(fileExtension: "zip", category: .archive),
        .init(fileExtension: "tar", category: .archive),
        .init(fileExtension: "gz", category: .archive),
        .init(fileExtension: "tgz", category: .archive),
        .init(fileExtension: "bz2", category: .archive),
        .init(fileExtension: "xz", category: .archive),
        .init(fileExtension: "rar", category: .archive),
        .init(fileExtension: "7z", category: .archive),
    ]

    static let schemes: [String] = [
        "http", "https", "mailto", "ssh", "ftp", "sftp", "magnet",
    ]

    static func fileTypes() -> [FileType] {
        entries.map { entry in
            let type = UTType(filenameExtension: entry.fileExtension)
            return FileType(
                id: entry.fileExtension,
                fileExtension: entry.fileExtension,
                utiIdentifier: type?.identifier ?? "dyn.\(entry.fileExtension)",
                typeName: type?.localizedDescription ?? entry.fileExtension.uppercased(),
                category: entry.category,
                handler: nil
            )
        }
    }
}
