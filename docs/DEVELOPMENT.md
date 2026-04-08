# MacRight 开发手册

> 本手册面向 macOS 开发初学者，从零开始讲解如何搭建环境、理解代码、构建调试、添加功能、打包分发。

---

## 目录

1. [基础概念](#1-基础概念)
2. [环境搭建](#2-环境搭建)
3. [项目结构详解](#3-项目结构详解)
4. [核心概念：Finder Sync Extension](#4-核心概念finder-sync-extension)
5. [构建与运行](#5-构建与运行)
6. [调试指南](#6-调试指南)
7. [代码逐文件详解](#7-代码逐文件详解)
8. [常见开发任务](#8-常见开发任务)
9. [App Sandbox 与权限](#9-app-sandbox-与权限)
10. [打包与分发](#10-打包与分发)
11. [常见问题与排错](#11-常见问题与排错)
12. [macOS 开发基础知识](#12-macos-开发基础知识)

---

## 1. 基础概念

### 1.1 什么是 macOS App Extension

macOS App Extension 是一种**独立于宿主 App 运行的小程序**，由系统按需加载。它不能单独分发，必须嵌入在一个宿主 App（Host App）内。

MacRight 的架构：

```
MacRight.app（宿主 App）
  └── Contents/PlugIns/
        └── FinderSyncExtension.appex（Finder 扩展）
```

- **宿主 App**：提供设置界面，引导用户启用扩展
- **扩展（.appex）**：实际提供右键菜单功能，由 Finder 进程加载

### 1.2 什么是 Finder Sync Extension

Apple 提供了 `FinderSync` 框架，允许第三方 App 在 Finder 中：
- 添加右键上下文菜单项
- 在文件/文件夹上叠加标记图标（badge）
- 添加工具栏按钮

MacRight 只使用了**右键菜单**功能。

### 1.3 宿主 App 与扩展的关系

| | 宿主 App | Finder Sync Extension |
|---|---|---|
| 进程 | 独立进程 | 由 Finder 加载，在 Finder 进程空间中运行 |
| UI 框架 | SwiftUI | AppKit（NSMenu） |
| 生命周期 | 用户控制 | 系统管理，随 Finder 启动/停止 |
| 文件访问 | 沙盒内 | 沙盒内，但可访问 Finder 当前目录 |
| 通信方式 | App Group 共享 UserDefaults | App Group 共享 UserDefaults |

### 1.4 关键术语

| 术语 | 解释 |
|------|------|
| **Bundle** | macOS 应用的打包格式，实际上是一个特定结构的文件夹 |
| **Bundle Identifier** | 应用的唯一标识符，如 `com.macright.app` |
| **App Group** | 允许同一开发者的多个 App/扩展共享数据的机制 |
| **Entitlements** | 声明 App 需要的系统权限（如文件访问、网络等） |
| **Code Signing** | 对 App 进行数字签名，macOS 要求所有 App 必须签名 |
| **Ad-hoc Signing** | 本地临时签名（`codesign --sign -`），无需 Apple Developer 账号 |
| **pluginkit** | macOS 管理扩展注册/启用的命令行工具 |
| **swiftc** | Swift 编译器命令行工具 |

---

## 2. 环境搭建

### 2.1 系统要求

- **macOS 13.0 (Ventura)** 或更高版本
- **Xcode Command Line Tools**（不需要完整的 Xcode）
- **Python 3**（用于生成模板文件，macOS 自带）

### 2.2 安装 Command Line Tools

打开终端，运行：

```bash
xcode-select --install
```

弹出对话框后点击"安装"。安装完成后验证：

```bash
# 检查 swiftc 是否可用
swiftc --version

# 检查 SDK 路径
xcrun --sdk macosx --show-sdk-path
# 应输出类似：/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

### 2.3 可选：安装完整 Xcode

如果你想用 Xcode IDE 开发（有代码补全、可视化调试等），可以从 Mac App Store 安装 Xcode。

安装后运行 `xcodegen` 生成 Xcode 项目：

```bash
# 安装 xcodegen（如果没有 Homebrew，先安装 Homebrew）
brew install xcodegen

# 在项目根目录生成 .xcodeproj
cd /path/to/mac-right
xcodegen generate
```

### 2.4 克隆项目

```bash
git clone <项目地址>
cd mac-right
```

### 2.5 生成模板文件

首次拉取代码后，需要生成 Office 空白模板：

```bash
python3 Scripts/create_templates.py
```

这会在 `FinderSyncExtension/Resources/Templates/` 下生成：
- `blank.docx` (~1 KB)
- `blank.xlsx` (~1 KB)
- `blank.pptx` (~3 KB)

---

## 3. 项目结构详解

```
mac-right/
├── build.sh                                # 一键构建脚本（核心！）
├── project.yml                             # xcodegen 配置（可选，用于生成 Xcode 项目）
│
├── MacRight/                               # 宿主 App 源码
│   ├── MacRightApp.swift                   # SwiftUI App 入口（@main）
│   ├── MacRight.entitlements               # 宿主 App 权限声明
│   ├── Views/
│   │   ├── ContentView.swift               # 主界面（扩展状态 + 引导）
│   │   └── SettingsView.swift              # 设置界面（终端选择、文件类型开关）
│   └── Info.plist                          # （由 build.sh 动态生成）
│
├── FinderSyncExtension/                    # Finder Sync 扩展源码
│   ├── FinderSync.swift                    # 扩展核心：菜单构建 + 事件处理
│   ├── FinderSyncExtension.entitlements    # 扩展权限声明
│   ├── Actions/
│   │   ├── FileCreator.swift               # 文件创建逻辑
│   │   └── TerminalLauncher.swift          # 打开终端逻辑
│   ├── Resources/
│   │   └── Templates/                      # Office 空白模板文件
│   │       ├── blank.docx
│   │       ├── blank.xlsx
│   │       └── blank.pptx
│   └── Info.plist                          # （由 build.sh 动态生成）
│
├── Shared/                                 # 宿主 App 和扩展共享的代码
│   ├── Constants.swift                     # 常量定义（App Group ID 等）
│   └── Preferences.swift                   # 偏好设置封装
│
├── Scripts/
│   └── create_templates.py                 # 生成空白 Office 模板
│
└── docs/
    ├── ARCHITECTURE.md                     # 架构设计文档
    └── DEVELOPMENT.md                      # 本文件（开发手册）
```

### 3.1 文件归属

每个 Swift 文件属于一个或两个 Target（编译目标）：

| 文件 | 宿主 App | 扩展 |
|------|:--------:|:----:|
| `MacRightApp.swift` | ✅ | |
| `ContentView.swift` | ✅ | |
| `SettingsView.swift` | ✅ | |
| `FinderSync.swift` | | ✅ |
| `FileCreator.swift` | | ✅ |
| `TerminalLauncher.swift` | | ✅ |
| `Constants.swift` | ✅ | ✅ |
| `Preferences.swift` | ✅ | ✅ |

---

## 4. 核心概念：Finder Sync Extension

### 4.1 工作原理

```
用户在 Finder 中右键
    ↓
Finder 检查已注册的 Finder Sync 扩展
    ↓
调用扩展的 menu(for:) 方法
    ↓
扩展返回 NSMenu（菜单项列表）
    ↓
Finder 将菜单项合并到右键菜单中
    ↓
用户点击某个菜单项
    ↓
Finder 通过 responder chain 调用对应的 @objc 方法
```

### 4.2 关键 API

```swift
// 注册监听的目录范围（"/" 表示全盘）
FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

// 获取 Finder 当前显示的目录
FIFinderSyncController.default().targetedURL()

// 获取用户选中的文件/文件夹
FIFinderSyncController.default().selectedItemURLs()
```

### 4.3 ⚠️ 重要注意事项

#### 不要设置菜单项的 target

```swift
// ❌ 错误！会导致点击菜单项无反应
let item = NSMenuItem(title: "新建文件", action: #selector(create(_:)), keyEquivalent: "")
item.target = self  // 千万不要这样做！

// ✅ 正确！让 Finder 通过 responder chain 路由
let item = NSMenuItem(title: "新建文件", action: #selector(create(_:)), keyEquivalent: "")
// 不设置 target，Finder 会自动找到你的扩展实例
```

**原因**：Finder Sync Extension 的菜单项由 Finder 进程管理。设置 `target = self` 会破坏 Finder 内部的消息路由机制（responder chain）。

#### 不要使用子菜单

macOS Sequoia (15.x) 上，Finder Sync Extension 的子菜单行为异常——父菜单会在子菜单展开前消失。这是系统级 bug/限制，没有已知的解决方案。

```swift
// ❌ 不要使用子菜单
let submenu = NSMenu()
submenu.addItem(...)
parentItem.submenu = submenu

// ✅ 使用扁平菜单
menu.addItem(NSMenuItem(title: "新建文本文件", action: #selector(createTxt(_:)), keyEquivalent: ""))
menu.addItem(NSMenuItem(title: "新建 Word 文档", action: #selector(createDocx(_:)), keyEquivalent: ""))
```

#### 扩展进程由系统管理

- 不要依赖实例变量保存持久状态（扩展随时可能被终止/重启）
- 需要持久化的数据应使用 UserDefaults（通过 App Group）

---

## 5. 构建与运行

### 5.1 一键构建（推荐）

```bash
cd /path/to/mac-right
./build.sh
```

`build.sh` 会依次执行：

1. **清理** — 删除上次的 `build/` 目录
2. **创建 Bundle 结构** — 按照 macOS App 规范创建目录
3. **编译宿主 App** — 用 `swiftc` 编译 MacRight 目标
4. **编译扩展** — 用 `swiftc` 编译 FinderSyncExtension 目标
5. **复制资源** — 将模板文件复制到扩展 Bundle
6. **生成 Info.plist** — 写入 Bundle 元数据
7. **代码签名** — 用 ad-hoc 签名
8. **安装** — 复制到 `/Applications/`
9. **注册扩展** — 用 `pluginkit` 激活
10. **启动 App** — 自动打开 MacRight.app

### 5.2 构建产物结构

构建后 `/Applications/MacRight.app` 的内部结构：

```
MacRight.app/
└── Contents/
    ├── Info.plist              # App 元数据
    ├── PkgInfo                 # "APPL????"
    ├── MacOS/
    │   └── MacRight            # 宿主 App 可执行文件
    ├── Resources/              # （当前为空）
    └── PlugIns/
        └── FinderSyncExtension.appex/
            └── Contents/
                ├── Info.plist          # 扩展元数据
                ├── MacOS/
                │   └── FinderSyncExtension  # 扩展可执行文件
                └── Resources/
                    └── Templates/      # Office 空白模板
                        ├── blank.docx
                        ├── blank.xlsx
                        └── blank.pptx
```

### 5.3 编译参数详解

宿主 App 编译命令：

```bash
swiftc \
  -sdk "$SDK_PATH" \                    # 指定 macOS SDK
  -target arm64-apple-macosx13.0 \      # 目标架构和最低系统版本
  -F "$SDK_PATH/System/Library/Frameworks" \  # Framework 搜索路径
  -framework Cocoa \                    # AppKit + Foundation
  -framework FinderSync \               # Finder Sync 框架
  -framework SwiftUI \                  # SwiftUI 框架
  -module-name MacRight \               # 模块名
  -emit-executable \                    # 输出可执行文件
  -o "输出路径" \
  文件1.swift 文件2.swift ...            # 源文件列表
```

扩展编译命令的特殊之处：

```bash
  -Xlinker -e -Xlinker _NSExtensionMain  # 指定入口点为 NSExtensionMain
                                          # 扩展没有 main()，由系统提供入口
```

### 5.4 首次运行后的操作

构建完成后，需要在系统设置中手动启用扩展：

1. 打开 **系统设置**
2. 进入 **通用** → **登录项与扩展**
3. 点击 **已添加的扩展**
4. 找到 **MacRight**，勾选 **Finder 扩展**

或者在 MacRight 宿主 App 中点击"打开系统设置 - 扩展"按钮。

---

## 6. 调试指南

### 6.1 查看扩展日志

扩展代码中的 `NSLog()` 输出可以通过以下方式查看：

```bash
# 实时查看所有 MacRight 相关日志
log stream --predicate 'process == "FinderSyncExtension" OR eventMessage CONTAINS "MacRight"' --level debug
```

按 `Ctrl+C` 停止。

### 6.2 检查扩展是否注册

```bash
# 列出所有已注册的 Finder Sync 扩展
pluginkit -m -p com.apple.FinderSync
```

输出应包含 `com.macright.app.FinderSyncExtension`。

### 6.3 强制重新注册扩展

如果扩展不生效，尝试：

```bash
# 杀掉缓存进程
killall pkd
sleep 1

# 重新启用
pluginkit -e use -i com.macright.app.FinderSyncExtension

# 重启 Finder
killall Finder
```

### 6.4 检查扩展进程是否在运行

```bash
ps aux | grep FinderSyncExtension
```

如果没有运行，说明扩展未被加载。打开一个 Finder 窗口并右键，系统应该会自动加载。

### 6.5 使用 Xcode 调试（可选）

1. 用 `xcodegen generate` 生成 `.xcodeproj`
2. 在 Xcode 中打开项目
3. 选择 FinderSyncExtension Scheme
4. 菜单 → Debug → Attach to Process by PID or Name → 输入 `FinderSyncExtension`
5. 在 Finder 中右键触发扩展
6. 断点和变量检查即可正常使用

### 6.6 常用调试命令速查

```bash
# 查看扩展注册状态
pluginkit -m -p com.apple.FinderSync

# 实时日志
log stream --predicate 'eventMessage CONTAINS "MacRight"'

# 检查 App 签名
codesign -dvv /Applications/MacRight.app
codesign -dvv /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex

# 检查 Entitlements
codesign -d --entitlements - /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex

# 查看 App Bundle 内容
ls -la /Applications/MacRight.app/Contents/
ls -la /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex/Contents/

# 重启 Finder
killall Finder
```

---

## 7. 代码逐文件详解

### 7.1 Shared/Constants.swift

```swift
enum AppConstants {
    static let appGroupID = "group.com.macright.app"
    static let extensionBundleID = "com.macright.app.FinderSyncExtension"
}
```

- `appGroupID`：App Group 标识符，宿主 App 和扩展共享数据的"频道"
- `extensionBundleID`：扩展的 Bundle Identifier，用于检查扩展是否启用

### 7.2 Shared/Preferences.swift

偏好设置管理类，核心设计：

```swift
final class Preferences {
    static let shared = Preferences()   // 单例模式

    private let defaults: UserDefaults

    private init() {
        // 使用 App Group 的 UserDefaults（非标准 UserDefaults）
        // 这样宿主 App 写入的设置，扩展也能读到
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    var preferredTerminal: TerminalApp { get/set }
    var enableDocx: Bool { get/set }
    var enableXlsx: Bool { get/set }
    var enablePptx: Bool { get/set }
}
```

**关键点**：
- 使用 `UserDefaults(suiteName:)` 而非 `UserDefaults.standard`
- 这是因为宿主 App 和扩展是**不同进程**，各自有独立的 `.standard`
- App Group 的 UserDefaults 是共享的，两边都能读写

### 7.3 FinderSyncExtension/FinderSync.swift

这是整个项目最核心的文件。

**初始化：**
```swift
override init() {
    super.init()
    // 告诉系统：我们要监听整个文件系统的右键事件
    FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
}
```

**菜单构建：**
```swift
override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "")
    let prefs = Preferences.shared

    // 始终显示"新建文本文件"
    menu.addItem(NSMenuItem(title: "新建文本文件",
                            action: #selector(createTxt(_:)),
                            keyEquivalent: ""))

    // 根据用户设置决定是否显示 Office 文件选项
    if prefs.enableDocx {
        menu.addItem(NSMenuItem(title: "新建 Word 文档",
                                action: #selector(createDocx(_:)),
                                keyEquivalent: ""))
    }
    // ... xlsx, pptx 类似

    menu.addItem(NSMenuItem(title: "在此打开终端",
                            action: #selector(openTerminal(_:)),
                            keyEquivalent: ""))
    return menu
}
```

**获取目标目录：**
```swift
private var targetDirectory: URL? {
    let targeted = FIFinderSyncController.default().targetedURL()

    // 如果用户右键点击了一个文件夹，则在该文件夹内创建文件
    if let items = FIFinderSyncController.default().selectedItemURLs() {
        for item in items {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
               isDir.boolValue {
                return item
            }
        }
    }
    // 否则在当前 Finder 窗口显示的目录中创建
    return targeted
}
```

**响应菜单点击：**
```swift
@objc func createTxt(_ sender: AnyObject?) {
    guard let dir = targetDirectory else { return }
    FileCreator.createFile(type: .txt, in: dir)
}
```

### 7.4 FinderSyncExtension/Actions/FileCreator.swift

**FileType 枚举：**
```swift
enum FileType: String, CaseIterable {
    case txt, docx, xlsx, pptx

    var templateName: String { "blank" }         // 所有模板都叫 blank
    var fileExtension: String { rawValue }        // 用 rawValue 作文件后缀
    var needsTemplate: Bool { self != .txt }      // txt 不需要模板

    var defaultFileName: String {
        switch self {
        case .txt:  return "未命名文本.txt"
        case .docx: return "未命名文档.docx"
        case .xlsx: return "未命名表格.xlsx"
        case .pptx: return "未命名演示.pptx"
        }
    }
}
```

**创建文件的三级 fallback：**

```
尝试 1: Data.write(to:options:.atomic)
  ↓ 失败
尝试 2: FileManager.default.createFile(atPath:contents:)
  ↓ 失败
尝试 3: /bin/cp 命令行复制
```

为什么需要多个 fallback？因为在沙盒环境下，不同的文件写入 API 在不同目录下的权限表现不同。

**文件名去重：**
```swift
private static func uniqueURL(for name: String, in directory: URL) -> URL {
    var candidate = directory.appendingPathComponent(name)
    var counter = 2
    while fileManager.fileExists(atPath: candidate.path) {
        let newName = "\(nameWithoutExt) \(counter).\(ext)"  // "未命名文档 2.docx"
        candidate = directory.appendingPathComponent(newName)
        counter += 1
    }
    return candidate
}
```

### 7.5 FinderSyncExtension/Actions/TerminalLauncher.swift

```swift
static func open(at directory: URL, using app: TerminalApp) {
    let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)

    // NSWorkspace.shared.open 是沙盒兼容的方式
    // 传入目录 URL，Terminal.app 会自动 cd 到该目录
    NSWorkspace.shared.open([directory], withApplicationAt: appURL, configuration: config)
}
```

**为什么不用 `Process` 启动终端？**
- `Process`（即 `NSTask`）在沙盒中可能受限
- `NSWorkspace.shared.open` 是 Apple 推荐的沙盒内启动其他 App 的方式

### 7.6 MacRight/MacRightApp.swift

```swift
@main
struct MacRightApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .windowResizability(.contentSize)   // 窗口大小跟随内容

        Settings { SettingsView() }             // Cmd+, 打开设置
    }
}
```

### 7.7 MacRight/Views/ContentView.swift

关键功能：
- **检测扩展状态**：通过运行 `pluginkit -m -p com.apple.FinderSync` 检查输出中是否包含我们的 Bundle ID
- **引导启用**：显示步骤说明和"打开系统设置"按钮
- **深度链接**：`x-apple.systempreferences:com.apple.ExtensionsPreferences` 直接打开系统设置的扩展页面

### 7.8 MacRight/Views/SettingsView.swift

SwiftUI 表单，使用 `@State` + `onChange` 同步到 `Preferences.shared`：

```swift
Toggle("Word 文档 (.docx)", isOn: $enableDocx)
    .onChange(of: enableDocx) { newValue in
        Preferences.shared.enableDocx = newValue
    }
```

**注意**：使用的是 macOS 13 兼容的 `onChange(of:) { newValue in }` API，而非 macOS 14+ 的 `onChange(of:initial:_:)`。

---

## 8. 常见开发任务

### 8.1 添加新的文件类型

以添加 Markdown (.md) 文件为例：

**第一步：修改 FileType 枚举**（`FileCreator.swift`）

```swift
enum FileType: String, CaseIterable {
    case txt
    case md        // 新增
    case docx
    case xlsx
    case pptx

    var needsTemplate: Bool {
        switch self {
        case .txt, .md: return false   // md 也不需要模板
        default: return true
        }
    }

    var defaultFileName: String {
        switch self {
        // ...
        case .md: return "未命名文档.md"    // 新增
        // ...
        }
    }
}
```

**第二步：在 FinderSync.swift 中添加菜单项和 action**

```swift
// 在 menu(for:) 中添加
menu.addItem(NSMenuItem(title: "新建 Markdown 文件",
                        action: #selector(createMd(_:)),
                        keyEquivalent: ""))

// 添加 action 方法
@objc func createMd(_ sender: AnyObject?) {
    guard let dir = targetDirectory else { return }
    FileCreator.createFile(type: .md, in: dir)
}
```

**第三步：如果需要偏好设置控制**（可选）

在 `Preferences.swift` 中添加：
```swift
var enableMd: Bool {
    get { defaults.object(forKey: "enableMd") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "enableMd") }
}
```

在 `SettingsView.swift` 中添加 Toggle。
在 `FinderSync.swift` 的 `menu(for:)` 中用 `if prefs.enableMd { ... }` 包裹。

**第四步：如果新文件类型需要模板**

1. 在 `FinderSyncExtension/Resources/Templates/` 下放入模板文件 `blank.md`
2. 确保 `FileType.needsTemplate` 对该类型返回 `true`
3. 在 `build.sh` 中确认模板复制命令覆盖到新文件

### 8.2 添加新的菜单功能

以添加"复制当前路径"为例：

```swift
// FinderSync.swift

// 1. 在 menu(for:) 中添加菜单项
menu.addItem(NSMenuItem(title: "复制当前路径",
                        action: #selector(copyPath(_:)),
                        keyEquivalent: ""))

// 2. 添加 action 方法
@objc func copyPath(_ sender: AnyObject?) {
    guard let dir = targetDirectory else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(dir.path, forType: .string)
}
```

### 8.3 修改默认文件名

编辑 `FileCreator.swift` 中 `FileType.defaultFileName`：

```swift
var defaultFileName: String {
    switch self {
    case .txt:  return "新建文本.txt"      // 改这里
    case .docx: return "新建文档.docx"     // 改这里
    // ...
    }
}
```

### 8.4 支持新的终端 App

以添加 Warp 为例：

```swift
// Preferences.swift
enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"        // 新增

    var bundleIdentifier: String {
        switch self {
        // ...
        case .warp: return "dev.warp.Warp-Stable"
        }
    }
}
```

无需修改 `TerminalLauncher.swift`——它通过 `bundleIdentifier` 通用地打开任何终端 App。

### 8.5 修改构建目标架构

当前 `build.sh` 编译为 `arm64`（Apple Silicon）。如果需要支持 Intel Mac：

```bash
# 改为 Universal Binary（同时支持 arm64 + x86_64）
-target arm64-apple-macosx13.0
# 改为：
-target x86_64-apple-macosx13.0   # 只支持 Intel
# 或者编译两次然后用 lipo 合并
```

---

## 9. App Sandbox 与权限

### 9.1 什么是 App Sandbox

App Sandbox 是 macOS 的安全机制，限制 App 只能访问自己"沙盒"内的资源。扩展必须启用沙盒，否则 `pluginkit` 拒绝注册。

### 9.2 Entitlements 文件解读

**扩展的 Entitlements**（`FinderSyncExtension.entitlements`）：

```xml
<!-- 必须为 true，否则 pluginkit 拒绝注册 -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- 允许读写用户选择的文件 -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- 允许读写用户主目录下的文件 -->
<key>com.apple.security.files.home-relative-path.read-write</key>
<array><string>/</string></array>

<!-- 允许读写下载目录 -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- 临时例外：允许更广泛的主目录访问 -->
<key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
<array><string>/</string></array>

<!-- App Group 共享 -->
<key>com.apple.security.application-groups</key>
<array><string>group.com.macright.app</string></array>
```

### 9.3 文件访问权限的实际表现

| 目录 | ad-hoc 签名 | Developer ID 签名 |
|------|:-----------:|:-----------------:|
| ~/Desktop | ✅ | ✅ |
| ~/Documents | ✅ | ✅ |
| ~/Downloads | ✅ | ✅ |
| ~/其他目录 | ✅ | ✅ |
| /Users | ❌ | ❌ |
| /tmp | ⚠️ | ⚠️ |
| /Applications | ❌ | ❌ |
| 外部硬盘 | ⚠️ | ✅（需额外 entitlement）|

`⚠️` 表示行为不确定，取决于系统版本和具体权限配置。

### 9.4 security-scoped resource

扩展中创建文件前会调用：

```swift
let accessing = directory.startAccessingSecurityScopedResource()
defer {
    if accessing { directory.stopAccessingSecurityScopedResource() }
}
```

这是为了在沙盒环境中获取对 Finder 传递过来的目录 URL 的访问权限。

---

## 10. 打包与分发

### 10.1 当前方式：ad-hoc 签名

`build.sh` 使用 `codesign --sign -`（ad-hoc 签名）。这意味着：
- ✅ 自己的 Mac 上可以正常使用
- ❌ 其他人首次打开会被 Gatekeeper 阻止（需右键 → 打开）
- ❌ `temporary-exception` entitlements 不生效
- ❌ 无法上架 Mac App Store

### 10.2 创建 DMG 安装包

```bash
# 创建 DMG
hdiutil create -volname "MacRight" \
    -srcfolder /Applications/MacRight.app \
    -ov -format UDZO \
    MacRight.dmg
```

### 10.3 正式分发（需要 Apple Developer 账号）

如果要正式分发，需要：

**1. 获取 Developer ID 证书**
- 注册 Apple Developer Program（$99/年）
- 在 Xcode 中创建 Developer ID 证书

**2. 用 Developer ID 签名**
```bash
# 替换 ad-hoc 签名为 Developer ID
codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
    --entitlements FinderSyncExtension/FinderSyncExtension.entitlements \
    /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex

codesign --force --sign "Developer ID Application: Your Name (TEAMID)" \
    --entitlements MacRight/MacRight.entitlements \
    /Applications/MacRight.app
```

**3. 公证（Notarization）**
```bash
# 打包为 zip
ditto -c -k --keepParent /Applications/MacRight.app MacRight.zip

# 提交公证
xcrun notarytool submit MacRight.zip \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "app-specific-password" \
    --wait

# 装订公证票据
xcrun stapler staple /Applications/MacRight.app
```

**4. 制作 DMG**
```bash
hdiutil create -volname "MacRight" \
    -srcfolder /Applications/MacRight.app \
    -ov -format UDZO \
    MacRight.dmg

# 公证 DMG
xcrun notarytool submit MacRight.dmg --apple-id ... --team-id ... --password ... --wait
xcrun stapler staple MacRight.dmg
```

---

## 11. 常见问题与排错

### Q1: 右键菜单中看不到 MacRight 的菜单项

**排查步骤：**

```bash
# 1. 检查扩展是否注册
pluginkit -m -p com.apple.FinderSync
# 应该能看到 com.macright.app.FinderSyncExtension

# 2. 如果看不到，检查 App 是否在 /Applications
ls /Applications/MacRight.app

# 3. 重新注册
killall pkd
sleep 1
pluginkit -e use -i com.macright.app.FinderSyncExtension
killall Finder

# 4. 检查系统设置中是否启用了扩展
# 系统设置 → 通用 → 登录项与扩展 → 已添加的扩展 → MacRight
```

### Q2: 菜单项点击后没反应（文件没创建）

**最可能的原因：** 菜单项设置了 `target`

检查 `FinderSync.swift` 中是否有类似代码：
```swift
item.target = self  // 删掉这行！
```

**其他原因：**
```bash
# 查看日志确认 action 是否被调用
log stream --predicate 'eventMessage CONTAINS "MacRight"'
# 然后在 Finder 中右键点击菜单项
```

### Q3: 文件创建失败（权限问题）

检查日志中的错误信息：
```bash
log stream --predicate 'eventMessage CONTAINS "MacRight"'
```

常见情况：
- **系统目录**（如 `/Users`、`/Applications`）：正常现象，沙盒不允许写入
- **用户目录**（如 `~/Desktop`）：如果也失败，检查 entitlements 是否正确

### Q4: 构建失败

```bash
# 检查 Command Line Tools 是否安装
xcode-select -p

# 检查 SDK 路径
xcrun --sdk macosx --show-sdk-path

# 如果 SDK 路径不对，重新选择
sudo xcode-select --switch /Library/Developer/CommandLineTools
# 或者（如果安装了 Xcode）
sudo xcode-select --switch /Applications/Xcode.app
```

### Q5: 构建成功但 pluginkit 报错 "plug-ins must be sandboxed"

确保扩展的 entitlements 文件中有：
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

### Q6: 菜单项重复出现

可能是 `build/` 目录和 `/Applications/` 中同时存在 App。`build.sh` 已经在安装后删除 build 目录中的 `.appex`，但如果你手动编译过，可能需要：

```bash
rm -rf build/
killall pkd
killall Finder
```

### Q7: 模板文件找不到（Office 文件创建失败）

```bash
# 检查模板是否存在于 App Bundle 内
ls /Applications/MacRight.app/Contents/PlugIns/FinderSyncExtension.appex/Contents/Resources/Templates/
# 应该能看到 blank.docx, blank.xlsx, blank.pptx
```

如果缺失，重新生成：
```bash
python3 Scripts/create_templates.py
./build.sh
```

### Q8: 其他人下载后无法打开

ad-hoc 签名的 App 会被 Gatekeeper 阻止。用户需要：
1. 右键点击 MacRight.app → "打开"
2. 在弹出的对话框中点击"打开"

正式解决方案是使用 Developer ID 签名 + 公证（见第 10 节）。

---

## 12. macOS 开发基础知识

### 12.1 macOS App Bundle 结构

每个 `.app` 文件实际上是一个文件夹（右键 → 显示包内容可以看到）：

```
MyApp.app/
└── Contents/
    ├── Info.plist          # App 元数据（名称、版本、Bundle ID 等）
    ├── PkgInfo             # 包类型标识
    ├── MacOS/
    │   └── MyApp           # 可执行文件
    ├── Resources/          # 资源文件（图片、模板等）
    ├── Frameworks/         # 依赖的框架
    └── PlugIns/            # 扩展（.appex）
```

### 12.2 Info.plist 关键字段

| 字段 | 含义 | 示例 |
|------|------|------|
| `CFBundleExecutable` | 可执行文件名 | `MacRight` |
| `CFBundleIdentifier` | Bundle ID | `com.macright.app` |
| `CFBundleName` | 显示名称 | `MacRight` |
| `CFBundleVersion` | 内部版本号 | `1` |
| `CFBundleShortVersionString` | 对外版本号 | `1.0.0` |
| `CFBundlePackageType` | 包类型 | `APPL`（App）/ `XPC!`（扩展）|
| `LSMinimumSystemVersion` | 最低系统版本 | `13.0` |
| `NSExtension` | 扩展配置 | 含扩展类型和入口类 |

### 12.3 代码签名

macOS 要求所有 App 都必须签名。签名类型：

| 签名类型 | 命令 | 适用场景 |
|----------|------|----------|
| Ad-hoc | `codesign --sign -` | 本地开发/测试 |
| Developer ID | `codesign --sign "Developer ID..."` | 分发给其他用户 |
| Mac App Store | 通过 Xcode 自动签名 | 上架 Mac App Store |

### 12.4 SwiftUI 基础

宿主 App 使用 SwiftUI 构建 UI：

```swift
@main
struct MacRightApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }  // 主窗口
        Settings { SettingsView() }    // Cmd+, 设置窗口
    }
}
```

- `@main`：标记 App 入口点
- `Scene`：窗口场景
- `WindowGroup`：主窗口
- `Settings`：设置窗口（按 Cmd+, 打开）
- `@State`：SwiftUI 的状态管理，值变化时自动刷新 UI

### 12.5 AppKit 基础

Finder Sync 扩展使用 AppKit：

- `NSMenu`：菜单容器
- `NSMenuItem`：菜单项
- `#selector`：Objective-C 运行时的方法选择器
- `@objc`：将 Swift 方法暴露给 Objective-C 运行时

### 12.6 常用终端命令

```bash
# Swift 编译
swiftc -o output file.swift             # 编译单个文件
swiftc -framework Cocoa file.swift      # 链接框架

# App 管理
open /Applications/MacRight.app         # 打开 App
killall MacRight                        # 终止 App 进程
killall Finder                          # 重启 Finder

# 代码签名
codesign --sign - app.app              # ad-hoc 签名
codesign -dvv app.app                  # 查看签名信息
codesign --verify app.app              # 验证签名

# 扩展管理
pluginkit -m -p com.apple.FinderSync   # 列出 Finder Sync 扩展
pluginkit -e use -i <bundle-id>        # 启用扩展
pluginkit -e ignore -i <bundle-id>     # 禁用扩展

# 日志
log stream --predicate 'eventMessage CONTAINS "关键词"'
```

---

## 附录：快速参考卡片

### 日常开发流程

```bash
# 1. 修改代码
vim FinderSyncExtension/FinderSync.swift

# 2. 构建安装
./build.sh

# 3. 在 Finder 中右键测试

# 4. 查看日志（如果有问题）
log stream --predicate 'eventMessage CONTAINS "MacRight"'
```

### 添加新功能的 checklist

- [ ] 在 `FinderSync.swift` 的 `menu(for:)` 中添加菜单项
- [ ] 添加对应的 `@objc` action 方法
- [ ] 如果需要偏好设置控制，在 `Preferences.swift` 中添加属性
- [ ] 如果需要偏好设置 UI，在 `SettingsView.swift` 中添加控件
- [ ] 如果需要模板文件，放入 `Resources/Templates/` 并更新 `FileType` 枚举
- [ ] 运行 `./build.sh` 测试
