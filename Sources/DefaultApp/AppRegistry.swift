import AppKit

/// 枚举本机已安装的 .app，用于候选应用列表。
enum AppRegistry {
    private static let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "\(NSHomeDirectory())/Applications",
        "/Developer/Applications",
        "/Applications/Xcode.app/Contents/Applications",
    ]

    private static let excludedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.loginwindow",
    ]

    /// 扫描并缓存。按名字排序。
    static func installedApps() -> [AppCandidate] {
        var results: [AppCandidate] = []
        var seen = Set<String>()

        for directory in searchPaths {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
                continue
            }
            for name in names where name.hasSuffix(".app") {
                let path = (directory as NSString).appendingPathComponent(name)
                guard let bundle = Bundle(url: URL(fileURLWithPath: path)),
                      let identifier = bundle.bundleIdentifier
                else { continue }
                guard !excludedBundleIDs.contains(identifier), !seen.contains(identifier) else { continue }
                seen.insert(identifier)
                results.append(
                    AppCandidate(
                        id: identifier,
                        name: (name as NSString).deletingPathExtension,
                        path: path
                    )
                )
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
