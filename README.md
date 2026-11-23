# DefaultApp

原生 macOS 默认应用管理器，基于 [`duti`](https://github.com/moretension/duti) 构建，纯 AppKit。

用图形界面查看和修改文件扩展名、URL Scheme 的默认打开应用，告别来回敲 `duti -s`。

## 为什么做这个

macOS 自带的「更改全部」按钮只能改当前文件，想批量查看和修改默认应用一直很麻烦。`duti` 命令行很好用，但没有一个跟得上系统设计的 GUI。

这个项目就是为了补上这一块：

- **纯 AppKit，无 SwiftUI** — 直接使用 `NSSplitViewController` + 系统玻璃材质
- **跟随 macOS 26 Liquid Glass** — 侧栏是真正的系统材质，不是自绘的假毛玻璃
- **零依赖运行** — 只需要系统里装有 `duti`

## 功能

- 按「文档 / 图片 / 音视频 / 开发文件 / 压缩包」分类浏览 64 种常见扩展名
- 管理 URL Scheme（`http` `https` `mailto` `ssh` `ftp` `sftp` `magnet`）的默认处理器
- 搜索框实时过滤扩展名和类型描述
- 点击任意行就地弹出应用选择菜单，带搜索
- 暂存改动，确认后一键「应用更改」，也可随时「恢复默认」
- 侧栏宽度可拖动，自动记忆

## 安装

### 依赖

```bash
brew install duti
```

### 从源码构建

需要 Xcode 26+ 和 macOS 26+。

```bash
git clone https://github.com/desperadoxhy/DefaultApp.git
cd DefaultApp
./scripts/build.sh
open "build/Default App.app"
```

构建脚本会自动完成编译、生成图标、签名。

## 实现说明

### 侧栏玻璃

按 WWDC25《Build an AppKit app with the new design》的做法，侧栏通过
`NSSplitViewItem(sidebarWithViewController:)` 创建，AppKit 自动提供玻璃材质、
浮动分隔条和折叠行为：

```swift
let item = NSSplitViewItem(sidebarWithViewController: sidebarHost)
item.minimumThickness = 180
item.maximumThickness = 400
addSplitViewItem(item)
```

**不要**在侧栏里自己叠 `NSVisualEffectView` — 那会挡住系统材质，也是很多人
做出「假毛玻璃」的原因。窗口也不要设 `isOpaque = false`，否则系统侧栏材质会失效。

### 侧栏宽度记忆

```swift
override func splitViewDidResizeSubviews(_ notification: Notification) {
    let width = splitView.subviews.first?.frame.width ?? 0
    guard width > 0 else { return }
    UserDefaults.standard.set(width, forKey: "sidebarWidth")
}
```

### 点击链路

列表行是 `NSTableCellView`，行内的 `NSTextField` 不能拦截鼠标，点击统一由
`tableView.target/action` 处理，这样整行可点且 `clickedRow` 正确：

```swift
tableView.target = self
tableView.action = #selector(rowClicked)
```

## 已知限制

- 依赖 `duti`，未安装时查询会失败并提示
- 扩展名清单是手工维护的（UTType 没有公开的「列出全部类型」接口），可以按需在 `AppCatalog.swift` 增删
- 目前只支持 Apple Silicon + macOS 26+

## 许可证

[MIT](LICENSE)
