import AppKit

/// 用 NSSplitViewController 承载左右两栏。
///
/// 按 Apple WWDC25「Build an AppKit app with the new design」的做法：
/// 侧栏用 NSSplitViewItem(sidebarWithViewController:) 创建，AppKit 会自动
/// 套上玻璃材质并处理好分隔条，不需要（也不应该）自己加 NSVisualEffectView。
final class ContentSplitController: NSSplitViewController {
    static let sidebarWidthKey = "sidebarWidth"
    private let sidebar: SidebarView
    private let content: ContentView
    private var suppressWidthSave = false

    init(sidebar: SidebarView, content: ContentView) {
        self.sidebar = sidebar
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarHost = NSViewController()
        sidebarHost.view = sidebar
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHost)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 400
        // 侧栏优先保持自己的宽度，窗口缩放时由内容区吸收变化。
        sidebarItem.holdingPriority = .defaultHigh
        sidebarItem.allowsFullHeightLayout = true
        addSplitViewItem(sidebarItem)

        let contentHost = NSViewController()
        contentHost.view = content
        let contentItem = NSSplitViewItem(viewController: contentHost)
        // 内容区的最小宽度由自身约束决定，不要硬设过大值，
        // 否则 AppKit 会把它当成窗口的最小尺寸。
        contentItem.minimumThickness = 320
        contentItem.holdingPriority = .defaultLow
        addSplitViewItem(contentItem)

        splitView.delegate = self

        // 侧栏是浮在内容上的玻璃面，靠玻璃边缘自然分界，
        // 不再画中间那条 1px 线（否则看起来像一条多余的缝）。
        splitView.dividerStyle = .thin
        // 等第一轮布局完成后再设置侧栏宽度，避免 setPosition 触发的
        // 重新布局把窗口压到最小尺寸。
        DispatchQueue.main.async { [weak self] in
            self?.restoreSidebarWidth()
        }
    }

    private func restoreSidebarWidth() {
        let saved = UserDefaults.standard.object(forKey: Self.sidebarWidthKey) as? CGFloat
        let width = saved.map { min(max($0, 180), 400) } ?? 220
        suppressWidthSave = true
        splitView.setPosition(width, ofDividerAt: 0)
        suppressWidthSave = false
    }

    private func saveSidebarWidth() {
        guard !suppressWidthSave else { return }
        let width = splitView.subviews.first?.frame.width ?? 0
        guard width > 0 else { return }
        UserDefaults.standard.set(width, forKey: Self.sidebarWidthKey)
    }
}

// MARK: - 记住侧栏宽度

extension ContentSplitController {
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        saveSidebarWidth()
    }
}
