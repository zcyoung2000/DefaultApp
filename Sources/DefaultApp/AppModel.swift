import AppKit

/// 管理类型清单与待应用的改动。
@MainActor
final class AppModel {
    private(set) var fileTypes: [FileType] = []
    private(set) var schemes: [URLScheme] = []
    private(set) var schemeLoaded: Set<String> = []

    var onChange: (() -> Void)?

    private let duti = DutiClient()
    /// 已改动但尚未写入系统的类型 id（普通类型用 "ext:<name>"，scheme 用 "scheme:<name>"）。
    private var stagedIDs: Set<String> = []

    init() {
        // 先用空 handler 渲染骨架，duti 查询放到后台，避免主线程被 70 次子进程阻塞。
        fileTypes = AppCatalog.fileTypes()
        schemes = AppCatalog.schemes.map { URLScheme(name: $0, handler: nil) }
    }

    func reload() {
        let client = duti
        let extensions = fileTypes.map(\.fileExtension)
        let schemeNames = schemes.map(\.name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var handlers: [String: AppCandidate] = [:]
            for ext in extensions {
                handlers[ext] = try? client.defaultHandler(forExtension: ext)
            }
            var schemeHandlers: [String: AppCandidate] = [:]
            for name in schemeNames {
                schemeHandlers[name] = try? client.defaultHandler(forScheme: name)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for index in self.fileTypes.indices {
                    self.fileTypes[index].handler = handlers[self.fileTypes[index].fileExtension] ?? nil
                    self.fileTypes[index].isLoaded = true
                }
                for index in self.schemes.indices {
                    self.schemes[index].handler = schemeHandlers[self.schemes[index].name] ?? nil
                    self.schemeLoaded.insert(self.schemes[index].name)
                }
                self.stagedIDs.removeAll()
                self.onChange?()
            }
        }
    }

    var pendingChangeCount: Int { stagedIDs.count }

    var hasPendingChanges: Bool { !stagedIDs.isEmpty }

    func isStaged(_ fileType: FileType) -> Bool {
        stagedIDs.contains(fileType.id)
    }

    func isSchemeStaged(_ name: String) -> Bool {
        stagedIDs.contains("scheme:" + name)
    }

    func stageScheme(handler: AppCandidate, scheme: String) {
        guard let index = schemes.firstIndex(where: { $0.name == scheme }) else { return }
        guard schemes[index].handler?.id != handler.id else { return }
        schemes[index].handler = handler
        stagedIDs.insert("scheme:" + scheme)
        onChange?()
    }

    func stage(handler: AppCandidate, for fileType: FileType) {
        guard let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) else { return }
        guard fileTypes[index].handler?.id != handler.id else { return }
        fileTypes[index].handler = handler
        stagedIDs.insert(fileType.id)
        onChange?()
    }

    func applyAll() -> Result<Void, Error> {
        for type in fileTypes where stagedIDs.contains(type.id) {
            guard let handler = type.handler else { continue }
            do {
                try duti.setDefaultHandler(bundleID: handler.id, forExtension: type.fileExtension)
            } catch {
                return .failure(error)
            }
        }
        for scheme in schemes where stagedIDs.contains("scheme:" + scheme.name) {
            guard let handler = scheme.handler else { continue }
            do {
                try duti.setDefaultHandler(bundleID: handler.id, forScheme: scheme.name)
            } catch {
                return .failure(error)
            }
        }
        stagedIDs.removeAll()
        onChange?()
        return .success(())
    }

    /// 放弃尚未应用的改动，恢复到系统当前的真实状态。
    func discardStagedChanges() {
        for id in stagedIDs {
            if id.hasPrefix("scheme:") {
                let name = String(id.dropFirst("scheme:".count))
                guard let index = schemes.firstIndex(where: { $0.name == name }) else { continue }
                schemes[index].handler = try? duti.defaultHandler(forScheme: name)
            } else {
                guard let index = fileTypes.firstIndex(where: { $0.id == id }) else { continue }
                fileTypes[index].handler = try? duti.defaultHandler(forExtension: fileTypes[index].fileExtension)
            }
        }
        stagedIDs.removeAll()
        onChange?()
    }
}

struct URLScheme: Identifiable, Hashable {
    let name: String
    var handler: AppCandidate?

    var id: String { name }
}
