import AppKit

final class MainWindowController: NSWindowController {
    private let model = AppModel()
    private let sidebar = SidebarView()
    private let content = ContentView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            // .titled 保留红绿灯；.fullSizeContentView 让侧栏玻璃铺到窗口顶端。
            // 不设 isOpaque=false / backgroundColor=.clear —— 那会废掉系统侧栏材质。
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "默认应用"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 760, height: 480)
        window.setContentSize(NSSize(width: 1000, height: 620))

        super.init(window: window)

        let split = ContentSplitController(sidebar: sidebar, content: content)
        // 注意：不能用 window.contentViewController —— 它会在每次布局时用
        // 约束的 fittingSize 反推窗口尺寸，把窗口压到 400+420=820。
        // 改用 contentView + childViewController 的组合，尺寸完全由窗口决定。
        addChildController(split, to: window)

        sidebar.selectionChanged = { [weak content] category in
            content?.select(category: category)
        }
        sidebar.schemeSelected = { [weak content] in
            content?.showSchemes()
        }
        content.configure(model: model)
        model.reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    func show() {
        // 明确落在主屏（screens.first，不是鼠标所在的 NSScreen.main）中央，
        // 避免 center() 把窗口丢到副屏。
        if let screen = NSScreen.screens.first {
            let size = NSSize(width: 1000, height: 620)
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
            window?.setFrame(NSRect(origin: origin, size: size), display: false)
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        // 玻璃材质和列表图标都依赖窗口上屏，等一帧后再渲染。
        DispatchQueue.main.async { [weak self] in
            self?.content.renderIfNeeded()
        }
    }

    private func addChildController(_ controller: NSViewController, to window: NSWindow) {
        // 关键：把根视图的 translatesAutoresizingMaskIntoConstraints 打开，
        // 让它用 frame/autoresizing 跟随窗口，而不是用约束反向决定窗口尺寸。
        let root = controller.view
        root.translatesAutoresizingMaskIntoConstraints = true
        root.autoresizingMask = [.width, .height]
        root.frame = NSRect(x: 0, y: 0, width: 1000, height: 620)
        window.contentView = root
    }
}
