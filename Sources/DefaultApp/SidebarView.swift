import AppKit

final class SidebarView: NSView {
    var selectionChanged: ((FileType.Category) -> Void)?
    var schemeSelected: (() -> Void)?

    private var buttons: [FileType.Category: SidebarRow] = [:]
    private var selected: FileType.Category = .all
    private var schemeRow: SidebarRow?

    init() {
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // 不加 NSVisualEffectView：WWDC25-310 明确说明侧栏材质由
        // NSSplitViewItem(sidebarWithViewController:) 提供，自绘会挡住它。

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        addSubview(stack)

        let title = makeLabel("分类", size: 11, weight: .semibold, color: .secondaryLabelColor)
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(8, after: title)

        for category in FileType.Category.allCases {
            let row = SidebarRow(category: category)
            row.target = self
            row.action = #selector(rowClicked(_:))
            buttons[category] = row
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let schemeTitle = makeLabel("链接", size: 11, weight: .semibold, color: .secondaryLabelColor)
        stack.addArrangedSubview(schemeTitle)
        stack.setCustomSpacing(14, after: buttons[.archive] ?? schemeTitle)

        let schemeRow = SidebarRow(title: "URL Scheme", symbol: "link")
        self.schemeRow = schemeRow
        schemeRow.target = self
        schemeRow.action = #selector(schemeClicked(_:))
        stack.addArrangedSubview(schemeRow)
        schemeRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 34),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        buttons[.all]?.isSelected = true
    }


    @objc private func rowClicked(_ sender: SidebarRow) {
        guard let category = FileType.Category.allCases.first(where: { buttons[$0] === sender }) else { return }
        select(category)
    }

    @objc private func schemeClicked(_ sender: SidebarRow) {
        // URL Scheme 是独立列表，切过去时清掉分类的选中态。
        buttons.values.forEach { $0.isSelected = false }
        sender.isSelected = true
        schemeSelected?()
    }

    func select(_ category: FileType.Category) {
        selected = category
        buttons.values.forEach { $0.isSelected = ($0.category == category) }
        schemeRow?.isSelected = false
        selectionChanged?(category)
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}

private final class SidebarRow: NSControl {
    let category: FileType.Category?

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: "")
    private var hoverTrackingArea: NSTrackingArea?

    var isSelected = false {
        didSet { updateAppearance() }
    }

    init(category: FileType.Category) {
        self.category = category
        super.init(frame: .zero)
        setup(symbol: category.symbolName, title: category.rawValue)
    }

    init(title: String, symbol: String) {
        self.category = nil
        super.init(frame: .zero)
        setup(symbol: symbol, title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(symbol: String, title: String) {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyDown

        label.stringValue = title
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        badge.stringValue = ""
        badge.font = NSFont.systemFont(ofSize: 11)
        badge.textColor = .tertiaryLabelColor
        badge.alignment = .right
        badge.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)
        addSubview(badge)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            badge.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 4),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            // 新系统侧栏的选中态：强调色胶囊，而不是整行铺满。
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
            iconView.contentTintColor = .controlAccentColor
            label.textColor = .controlAccentColor
            badge.textColor = .controlAccentColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = .secondaryLabelColor
            label.textColor = .labelColor
            badge.textColor = .tertiaryLabelColor
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.16).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isSelected {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    func setBadge(_ text: String) {
        badge.stringValue = text
    }
}
