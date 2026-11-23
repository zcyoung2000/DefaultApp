import AppKit

/// 弹出式应用选择菜单：带搜索框，逐项列出已安装应用。
final class AppPickerMenu: NSMenu {
    private(set) var selectedCandidate: AppCandidate?

    private var allCandidates: [AppCandidate] = []
    private var currentBundleID: String?
    private var searchItem: NSMenuItem?
    private var searchField: NSSearchField?

    init(title: String, candidates: [AppCandidate], current: AppCandidate?) {
        super.init(title: title)
        allCandidates = candidates
        currentBundleID = current?.id
        build()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let header = NSMenuItem(title: "选择默认应用", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: header.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        addItem(header)

        let searchViewItem = NSMenuItem()
        let field = NSSearchField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "搜索应用"
        field.font = NSFont.systemFont(ofSize: 12)
        field.sendsWholeSearchString = false
        field.target = self
        field.action = #selector(filterChanged)
        field.translatesAutoresizingMaskIntoConstraints = true
        field.autoresizingMask = [.width]
        searchField = field
        searchViewItem.view = field
        addItem(searchViewItem)
        searchItem = searchViewItem

        addItem(.separator())

        for candidate in allCandidates {
            let item = NSMenuItem(
                title: candidate.name,
                action: #selector(candidateClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = candidate.id
            item.image = candidate.icon()
            item.image?.size = NSSize(width: 18, height: 18)
            item.state = (candidate.id == currentBundleID) ? .on : .off
            addItem(item)
        }
    }

    @objc private func filterChanged() {
        let text = searchField?.stringValue ?? ""
        let selector = #selector(candidateClicked(_:))
        for item in items where item.action == selector {
            item.isHidden = !text.isEmpty && !(item.title.localizedCaseInsensitiveContains(text))
        }
    }

    @objc private func candidateClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        selectedCandidate = allCandidates.first { $0.id == id }
    }
    /// 在给定视图的指定位置弹出菜单。
    ///
    /// `location` 是 `view` 坐标系中的点；这里先转成屏幕坐标再传给
    /// `popUp(in: nil)`，因为传 nil 时 AppKit 要求的是屏幕坐标。
    func popUp(positioning: NSMenuItem?, at location: NSPoint, in view: NSView) -> Bool {
        guard let window = view.window else { return false }
        // popUp(in: nil) 的 at 是「屏幕坐标」。把点击点转成屏幕坐标后，
        // 再按菜单宽度左移，让菜单右边缘对齐锚点（不会跑到离点击点很远的地方）。
        let screenPoint = window.convertPoint(toScreen: view.convert(location, to: nil))
        let width = estimatedMenuWidth()
        // 右对齐锚点，但不要跑到屏幕左边界之外。
        let minX = window.screen?.visibleFrame.minX ?? 0
        let anchored = NSPoint(
            x: max(screenPoint.x - width, minX),
            y: screenPoint.y
        )
        super.popUp(positioning: positioning, at: anchored, in: nil)
        return selectedCandidate != nil
    }

    private func estimatedMenuWidth() -> CGFloat {
        var width: CGFloat = 0
        for item in items where !item.isSeparatorItem {
            let attributed = NSAttributedString(
                string: item.title,
                attributes: [.font: NSFont.menuFont(ofSize: 0)]
            )
            width = max(width, attributed.size().width)
        }
        // 勾选列 + 图标 + 左右内边距
        return min(width + 76, 400)
    }
}
