import AppKit

final class ContentView: NSView {
    private var model: AppModel?

    private let searchField = NSSearchField()
    private let discardButton = NSButton(title: "恢复默认", target: nil, action: nil)
    private let applyButton = NSButton(title: "应用更改", target: nil, action: nil)
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "没有匹配的类型")

    private var rows: [FileType] = []
    private var currentCategory: FileType.Category = .all
    private var showsSchemes = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索扩展名或类型"
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.sendsWholeSearchString = false
        searchField.target = self
        searchField.action = #selector(searchChanged)

        discardButton.translatesAutoresizingMaskIntoConstraints = false
        discardButton.bezelStyle = .rounded
        discardButton.controlSize = .large
        discardButton.font = NSFont.systemFont(ofSize: 12.5)
        discardButton.target = self
        discardButton.action = #selector(discardClicked)
        discardButton.isEnabled = false

        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .large
        applyButton.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        applyButton.target = self
        applyButton.action = #selector(applyClicked)
        applyButton.isEnabled = false
        applyButton.keyEquivalent = "\r"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.rowHeight = 38
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.allowsEmptySelection = true
        // 关键：行内所有子控件都不能拦截鼠标，否则点击落不到表格上。
        tableView.style = .fullWidth
        tableView.selectionHighlightStyle = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        column.width = 600
        tableView.addTableColumn(column)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = NSFont.systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.isHidden = true

        addSubview(searchField)
        addSubview(discardButton)
        addSubview(applyButton)
        addSubview(scrollView)
        addSubview(emptyLabel)

        let toolbar = NSStackView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.addArrangedSubview(searchField)
        toolbar.addArrangedSubview(discardButton)
        toolbar.addArrangedSubview(applyButton)
        // 搜索框占据剩余宽度，按钮保持自身大小。
        toolbar.setCustomSpacing(0, after: searchField)
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        discardButton.setContentHuggingPriority(.required, for: .horizontal)
        applyButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(toolbar)

        NSLayoutConstraint.activate([
            searchField.heightAnchor.constraint(equalToConstant: 28),

            // 顶部留出红绿灯高度，搜索框不会被窗口按钮压住。
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),

            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(model: AppModel) {
        self.model = model
        model.onChange = { [weak self] in
            self?.render()
        }
    }

    /// 窗口上屏后再渲染，避免离屏状态下加载图标卡住。
    func renderIfNeeded() {
        render()
    }

    func select(category: FileType.Category) {
        currentCategory = category
        showsSchemes = false
        render()
    }

    func showSchemes() {
        showsSchemes = true
        render()
    }

    @objc private func searchChanged() {
        render()
    }

    @objc private func rowClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < rows.count else { return }
        let type = rows[row]
        let rowView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) ?? tableView
        openPicker(for: type, sourceView: rowView)
    }

    @objc private func discardClicked() {
        model?.discardStagedChanges()
    }

    @objc private func applyClicked() {
        guard let model else { return }
        if case let .failure(error) = model.applyAll() {
            guard let window else { return }
            NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
        }
    }

    private func render() {
        guard let model else { return }

        let searchText = searchField.stringValue.trimmingCharacters(in: .whitespaces)

        if showsSchemes {
            var visibleSchemes = model.schemes
            if !searchText.isEmpty {
                visibleSchemes = visibleSchemes.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
            }
            rows = visibleSchemes.map {
                var row = FileType(
                    id: "scheme:" + $0.name,
                    fileExtension: $0.name,
                    utiIdentifier: "",
                    typeName: "URL Scheme",
                    category: .all,
                    handler: $0.handler
                )
                row.isLoaded = model.schemeLoaded.contains($0.name)
                return row
            }
            tableView.reloadData()
            emptyLabel.isHidden = !rows.isEmpty
            applyButton.title = model.hasPendingChanges
                ? "应用更改 \(model.pendingChangeCount)"
                : "应用更改"
            applyButton.isEnabled = model.hasPendingChanges
            discardButton.isEnabled = model.hasPendingChanges
            return
        }

        var visible = model.fileTypes
        if currentCategory != .all {
            visible = visible.filter { $0.category == currentCategory }
        }
        if !searchText.isEmpty {
            visible = visible.filter {
                $0.fileExtension.localizedCaseInsensitiveContains(searchText)
                    || $0.typeName.localizedCaseInsensitiveContains(searchText)
            }
        }

        rows = visible
        tableView.reloadData()
        emptyLabel.isHidden = !visible.isEmpty

        applyButton.title = model.hasPendingChanges ? "应用更改 \(model.pendingChangeCount)" : "应用更改"
        applyButton.isEnabled = model.hasPendingChanges
        discardButton.isEnabled = model.hasPendingChanges
    }
}

// MARK: - NSTableView 数据与视图

extension ContentView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let type = rows[row]
        let identifier = NSUserInterfaceItemIdentifier("TypeRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: nil) as? TypeRow
            ?? TypeRow(fileType: type)

        let staged = type.id.hasPrefix("scheme:")
            ? (model?.isSchemeStaged(type.fileExtension) ?? false)
            : (model?.isStaged(type) ?? false)
        rowView.configure(type: type, staged: staged)
        rowView.onMenuRequest = { [weak self] in
            self?.openPicker(for: type, sourceView: rowView)
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }

    func openPicker(for type: FileType, sourceView: NSView) {
        guard let model else { return }
        // 菜单贴着该行右侧的应用名弹出（向下展开），而不是贴到行左上角。
        let anchor = NSPoint(
            x: sourceView.bounds.maxX - 20,
            y: sourceView.bounds.midY
        )
        if showsSchemes {
            let scheme = type.fileExtension
            let menu = AppPickerMenu(
                title: scheme,
                candidates: AppRegistry.installedApps(),
                current: type.handler
            )
            _ = menu.popUp(positioning: nil, at: anchor, in: sourceView)
            if let picked = menu.selectedCandidate {
                model.stageScheme(handler: picked, scheme: scheme)
            }
        } else {
            let menu = AppPickerMenu(
                title: type.fileExtension,
                candidates: AppRegistry.installedApps(),
                current: type.handler
            )
            _ = menu.popUp(positioning: nil, at: anchor, in: sourceView)
            if let picked = menu.selectedCandidate {
                model.stage(handler: picked, for: type)
            }
        }
    }
}
