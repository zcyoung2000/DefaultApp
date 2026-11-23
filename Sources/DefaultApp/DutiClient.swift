import AppKit

enum DutiError: LocalizedError {
    case missingBinary
    case failed(command: String, status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .missingBinary:
            return "未找到 duti。请先运行 brew install duti。"
        case let .failed(command, status, output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "duti 执行失败（\(command)，退出码 \(status)）"
                : detail
        }
    }
}

/// 围绕 duti 命令行的薄封装，不直接触碰 LaunchServices 私有 API。
struct DutiClient {
    private let binaryURL: URL?

    init() {
        binaryURL = Self.locate()
    }

    var isAvailable: Bool { binaryURL != nil }

    private static func locate() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/duti",
            "/usr/local/bin/duti",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map(URL.init(fileURLWithPath:))
    }

    /// 查询某个扩展名的默认处理器。
    func defaultHandler(forExtension ext: String) throws -> AppCandidate? {
        let out = try run(["-x", ext])
        let lines = out.split(separator: "\n").map(String.init)
        guard lines.count >= 3 else { return nil }
        let path = lines[1].trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        return AppCandidate(
            id: lines[2].trimmingCharacters(in: .whitespaces),
            name: lines[0].trimmingCharacters(in: .whitespaces),
            path: path
        )
    }

    /// 查询某个 URL scheme 的默认处理器。
    func defaultHandler(forScheme scheme: String) throws -> AppCandidate? {
        let bundleID = try run(["-d", scheme]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleID.isEmpty else { return nil }
        return candidate(forBundleID: bundleID)
    }

    /// 设置默认处理器。
    func setDefaultHandler(bundleID: String, forExtension ext: String) throws {
        _ = try run(["-s", bundleID, ext])
    }

    func setDefaultHandler(bundleID: String, forScheme scheme: String) throws {
        _ = try run(["-s", bundleID, scheme])
    }

    /// 找出某个 bundle id 对应的 app，用于展示图标和名字。
    func candidate(forBundleID bundleID: String) -> AppCandidate? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = (url.path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            return AppCandidate(id: bundleID, name: name, path: url.path)
        }
        return AppCandidate(id: bundleID, name: bundleID, path: "")
    }

    private func run(_ arguments: [String]) throws -> String {
        guard let binaryURL else { throw DutiError.missingBinary }
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: outData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errData, encoding: .utf8) ?? ""

        // duti 对没有处理器的扩展名返回 2，这不是错误。
        if process.terminationStatus == 2 {
            return output
        }
        guard process.terminationStatus == 0 else {
            throw DutiError.failed(
                command: ([binaryURL.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: errorOutput
            )
        }
        return output
    }
}
