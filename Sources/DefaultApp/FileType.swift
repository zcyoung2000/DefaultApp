import Foundation
import AppKit
import UniformTypeIdentifiers

/// 一个可被管理的文件类型：一个扩展名 + 其 UTI + 当前默认应用。
struct FileType: Identifiable, Hashable {
    let id: String
    let fileExtension: String
    let utiIdentifier: String
    let typeName: String
    let category: Category
    var handler: AppCandidate?
    /// duti 是否已查询过。未查询时不显示「未设置」的橙色标记。
    var isLoaded = false

    enum Category: String, CaseIterable, Identifiable {
        case all = "全部类型"
        case document = "文档"
        case image = "图片"
        case media = "音视频"
        case code = "开发文件"
        case archive = "压缩包"

        var id: String { rawValue }

        var symbolName: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .document: return "doc.text"
            case .image: return "photo"
            case .media: return "music.note"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .archive: return "shippingbox"
            }
        }
    }
}

/// 候选应用。
struct AppCandidate: Identifiable, Hashable {
    let id: String          // bundle identifier
    let name: String
    let path: String

    func icon() -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
