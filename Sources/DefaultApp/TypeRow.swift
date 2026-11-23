import AppKit
import UniformTypeIdentifiers

/// 列表中的一行：文件类型图标 + 扩展名 + 类型描述 + 当前默认应用。
final class TypeRow: NSTableCellView {
    var onMenuRequest: (() -> Void)?

    private var fileType: FileType?
    private var staged = false

    private let iconView = NSImageView()
    private let extLabel = NSTextField(labelWithString: "")
    private let typeLabel = NSTextField(labelWithString: "")
    private let appStack = NSStackView()
    private let separator = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(fileType: FileType) {
        self.init(frame: .zero)
        configure(type: fileType, staged: false)
    }

    private func build() {
        identifier = NSUserInterfaceItemIdentifier("TypeRow")
        wantsLayer = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        extLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        extLabel.textColor = .labelColor
        extLabel.translatesAutoresizingMaskIntoConstraints = false

        typeLabel.font = NSFont.systemFont(ofSize: 12.5)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        appStack.translatesAutoresizingMaskIntoConstraints = false
        appStack.orientation = .horizontal
        appStack.spacing = 7
        appStack.alignment = .centerY

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(extLabel)
        addSubview(typeLabel)
        addSubview(appStack)
        addSubview(separator)

        // 关键：行内所有子控件都必须「不拦截鼠标」，否则点击会被
        // NSTextField 吃掉，tableView.action 永远收不到。
        for field in [extLabel, typeLabel] {
            field.isSelectable = false
            field.isEditable = false
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            extLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            extLabel.widthAnchor.constraint(equalToConstant: 96),
            extLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            typeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 190),
            typeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            appStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            appStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            appStack.leadingAnchor.constraint(greaterThanOrEqualTo: typeLabel.trailingAnchor, constant: 8),
            appStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        appStack.setContentHuggingPriority(.required, for: .horizontal)
        appStack.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func configure(type: FileType, staged: Bool) {
        self.fileType = type
        self.staged = staged

        let isScheme = type.id.hasPrefix("scheme:")
        if isScheme {
            iconView.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
            iconView.contentTintColor = .secondaryLabelColor
            extLabel.stringValue = type.fileExtension
        } else {
            let uti = UTType(filenameExtension: type.fileExtension) ?? .data
            iconView.image = NSWorkspace.shared.icon(for: uti)
            iconView.contentTintColor = nil
            extLabel.stringValue = "." + type.fileExtension
        }
        typeLabel.stringValue = type.typeName

        rebuildHandlerViews()
        updateBackground()
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(type.fileExtension)，当前默认应用 \(type.handler?.name ?? "未设置")")
    }

    private func rebuildHandlerViews() {
        appStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown

        let name = NSTextField(labelWithString: "")
        name.font = NSFont.systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingTail
        name.translatesAutoresizingMaskIntoConstraints = false

        let arrow = NSImageView()
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
        arrow.contentTintColor = .tertiaryLabelColor

        if let handler = fileType?.handler {
            icon.image = handler.icon()
            name.stringValue = handler.name
            name.textColor = .labelColor
        } else if fileType?.isLoaded == true {
            icon.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
            icon.contentTintColor = .systemOrange
            name.stringValue = "未设置"
            name.textColor = .systemOrange
        } else {
            // duti 还没返回，先显示中性占位，避免首帧整列橙色。
            icon.image = nil
            name.stringValue = ""
            name.textColor = .tertiaryLabelColor
        }

        appStack.addArrangedSubview(icon)
        appStack.addArrangedSubview(name)
        appStack.addArrangedSubview(arrow)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            arrow.widthAnchor.constraint(equalToConstant: 10),
        ])
    }

    private func updateBackground() {
        if staged {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        } else if fileType?.isLoaded == true, fileType?.handler == nil {
            // 只有 duti 查询完成且确实没有默认应用时才标橙，
            // 避免首帧把所有行都刷成橙色。
            layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.08).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    /// 不覆盖 hitTest / mouseDown：点击必须落到 NSTableView 上，
    /// 由 tableView.target/action 统一处理，这样整行都可点且 clickedRow 正确。
}
