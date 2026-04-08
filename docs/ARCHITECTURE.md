# MacRight 架构设计文档

## 1. 项目概述

MacRight 是一款 macOS Finder 右键菜单扩展工具，为 Finder 添加以下功能：
- 新建文本文件 (.txt)
- 新建 Word 文档 (.docx)
- 新建 Excel 表格 (.xlsx)
- 新建 PowerPoint 演示 (.pptx)
- 在当前目录打开终端 (Terminal / iTerm)

macOS 长期缺少类似 Windows 的「新建文件」右键菜单功能，MacRight 填补了这一空白。

---

## 2. 技术选型

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 核心 API | Finder Sync Extension | Apple 唯一官方支持的 Finder 右键菜单扩展方案 |
| 开发语言 | Swift 5.9+ | Apple 主力语言，类型安全，现代语法 |
| 宿主 App UI | SwiftUI | 宿主 App 功能简单（状态展示+设置），SwiftUI 开发效率高 |
| 扩展 UI | AppKit (NSMenu) | Finder Sync API 强制要求使用 NSMenu |
| 最低系统版本 | macOS 13.0 (Ventura) | SwiftUI 功能成熟，覆盖主流 Mac 用户 |
| 构建工具 | swiftc + shell 脚本 | 无需完整 Xcode，仅需 Command Line Tools |
| 项目管理 | xcodegen + project.yml | 声明式项目配置，可在有 Xcode 时生成 .xcodeproj |
| 文件创建方案 | 模板复制 | 内置最小空白 Office 模板文件，复制+重命名，简单可靠 |
| 第三方依赖 | 无 | Foundation + FinderSync + SwiftUI 覆盖所有需求 |
| 签名方式 | Ad-hoc (开发) / Developer ID (发布) | 扩展必须签名才能被系统发现 |
| 分发方式 | DMG 直接分发 | 「打开终端」功能在 App Store 沙盒下受限 |

### 2.1 为什么选择 Finder Sync Extension

macOS 上扩展 Finder 右键菜单有以下方案，对比如下：

| 方案 | 右键菜单 | 文件系统集成 | App Store 兼容 | 稳定性 |
|------|----------|-------------|---------------|--------|
| **Finder Sync Extension** | 直接添加到右键菜单 | 完整目录监听 | 是 | 高（Apple 官方 API） |
| Services Menu | 在子菜单「服务」中 | 有限 | 是 | 中 |
| Automator Quick Actions | 操作较笨重 | 有限 | 否 | 低（逐渐废弃） |
| AppleScript/Shell Hack | 脆弱、无官方支持 | 无 | 否 | 极低（跨版本易失效） |

Finder Sync Extension 是唯一能**直接在右键菜单顶层添加菜单项**的官方 API。

---

## 3. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                     MacRight.app (宿主应用)                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ SwiftUI App                                            │  │
│  │ - ContentView: 扩展状态、启用引导                        │  │
│  │ - SettingsView: 偏好设置（终端选择、文件类型开关）         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ FinderSyncExtension.appex (Finder Sync 扩展)           │  │
│  │                                                        │  │
│  │ FinderSync.swift ──── menu(for:) 提供右键菜单           │  │
│  │       │                                                │  │
│  │       ├── FileCreator ──── 复制模板创建文件              │  │
│  │       │       └── Resources/Templates/ (空白模板)       │  │
│  │       │                                                │  │
│  │       └── TerminalLauncher ──── NSWorkspace 打开终端    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Shared/ (共享代码)                                      │  │
│  │ - Constants.swift: App Group ID 等常量                   │  │
│  │ - Preferences.swift: UserDefaults 封装                   │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

通信方式: App Group 共享 UserDefaults (group.com.macright.app)
```

### 3.1 双 Target 架构

项目包含两个编译目标：

**Target 1: MacRight (宿主应用)**
- 类型：macOS Application (.app)
- 框架：SwiftUI
- 职责：
  - 显示扩展启用状态
  - 引导用户在系统设置中启用扩展
  - 提供偏好设置界面
- Bundle ID: `com.macright.app`

**Target 2: FinderSyncExtension (Finder Sync 扩展)**
- 类型：App Extension (.appex)
- 框架：AppKit + FinderSync
- 职责：
  - 向 Finder 右键菜单注入菜单项
  - 执行文件创建、终端打开等操作
- Bundle ID: `com.macright.app.FinderSyncExtension`
- 嵌入位置：`MacRight.app/Contents/PlugIns/FinderSyncExtension.appex`

### 3.2 为什么需要宿主 App

macOS 要求 App Extension 必须嵌入在一个宿主 App 中，不能独立分发。宿主 App 的作用：
1. 作为扩展的载体（.appex 放在 .app 的 PlugIns 目录下）
2. 让系统发现和注册扩展
3. 提供用户界面（设置、引导）
4. 通过 App Group 与扩展共享偏好设置

---

## 4. 目录结构

```
mac-right/
├── MacRight.xcodeproj/                    # Xcode 项目（xcodegen 生成）
├── project.yml                            # xcodegen 声明式配置
├── build.sh                               # 一键构建+签名+安装脚本
│
├── MacRight/                              # TARGET 1: 宿主 App
│   ├── MacRightApp.swift                  # @main SwiftUI 入口
│   ├── Views/
│   │   ├── ContentView.swift              # 主界面
│   │   └── SettingsView.swift             # 偏好设置
│   ├── Assets.xcassets/                   # 图标和颜色资源
│   ├── Info.plist                         # App 元数据
│   └── MacRight.entitlements              # App 权限声明
│
├── FinderSyncExtension/                   # TARGET 2: Finder Sync 扩展
│   ├── FinderSync.swift                   # 核心：FIFinderSync 子类
│   ├── Actions/
│   │   ├── FileCreator.swift              # 文件创建逻辑
│   │   └── TerminalLauncher.swift         # 终端启动逻辑
│   ├── Resources/Templates/               # 空白 Office 模板
│   │   ├── blank.docx                     # 1.2 KB
│   │   ├── blank.xlsx                     # 1.5 KB
│   │   └── blank.pptx                     # 3.6 KB
│   ├── Info.plist                         # 扩展元数据
│   └── FinderSyncExtension.entitlements   # 扩展权限声明
│
├── Shared/                                # 两个 Target 共享代码
│   ├── Constants.swift                    # 常量定义
│   └── Preferences.swift                  # 偏好设置封装
│
├── Scripts/
│   └── create_templates.py                # 模板文件生成脚本
│
├── build/                                 # 构建输出（git ignored）
│   └── MacRight.app/
└── dist/                                  # 分发包输出
    └── MacRight-1.0.0.dmg
```

---

## 5. 核心模块详解

### 5.1 FinderSync.swift — 扩展核心

这是整个项目最核心的文件，继承自 `FIFinderSync`。

**生命周期**：
- 扩展进程由 macOS 系统管理，不是常驻运行
- 用户在 Finder 中右键时，系统按需启动扩展进程
- 空闲一段时间后系统自动终止

**关键方法**：

```
init()
  └── 设置 directoryURLs = ["/"]  // 监听全盘，所有目录都显示菜单

menu(for: FIMenuKind) -> NSMenu
  └── 构建右键菜单项，每次右键都会调用
  └── 返回的 NSMenu 中的项目会被 Finder 插入到右键菜单中

createTxt/Docx/Xlsx/Pptx(_ sender:)
  └── 菜单项的 action 方法，Finder 通过 responder chain 调用

openTerminal(_ sender:)
  └── 打开终端 action

targetDirectory -> URL?
  └── 确定文件创建的目标目录
  └── 优先使用选中的文件夹，否则使用当前 Finder 窗口的目录
```

**关于 Action 路由**：
Finder Sync 扩展的菜单项 **不能** 设置 `item.target = self`。Finder 通过自己的 responder chain 将 action 分发到 FIFinderSync 子类。设置了 target 反而会导致 action 无法触发。

### 5.2 FileCreator.swift — 文件创建

**文件类型定义**：

| 类型 | 扩展名 | 默认文件名 | 创建方式 |
|------|--------|-----------|---------|
| txt | .txt | 未命名文本.txt | 创建空文件 |
| docx | .docx | 未命名文档.docx | 复制模板 |
| xlsx | .xlsx | 未命名表格.xlsx | 复制模板 |
| pptx | .pptx | 未命名演示.pptx | 复制模板 |

**创建流程**：

```
createFile(type, in: directory)
  │
  ├── 1. startAccessingSecurityScopedResource() // 请求沙盒访问权限
  ├── 2. uniqueURL() // 生成不冲突的文件名
  │       └── 未命名文档.docx → 未命名文档 2.docx → 未命名文档 3.docx
  │
  ├── [txt] Data().write() // 直接写空数据
  │
  └── [docx/xlsx/pptx]
      ├── 3a. Bundle.main.url(forResource:) // 从扩展 Bundle 读取模板
      ├── 3b. Data(contentsOf:).write(to:) // 写入目标路径
      │
      ├── 失败后备 → FileManager.createFile()
      └── 再失败后备 → /bin/cp 命令行复制
```

**模板文件**：
- 内置于扩展 Bundle 的 `Resources/Templates/` 目录
- 由 `Scripts/create_templates.py` 一次性生成
- 是最小有效的 Office Open XML 文件（ZIP 格式包含必要的 XML）
- 总计仅 ~6 KB，不会影响 App 体积

### 5.3 TerminalLauncher.swift — 终端启动

使用 `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` API：

```
open(at: directory, using: app)
  │
  ├── 1. NSWorkspace.urlForApplication(withBundleIdentifier:)
  │       └── 查找终端 App 的路径
  │
  └── 2. NSWorkspace.shared.open([directory], withApplicationAt:, configuration:)
          └── 用指定终端 App 打开目录
          └── Terminal.app 原生支持打开文件夹时自动 cd
```

支持的终端：
- Terminal.app (`com.apple.Terminal`)
- iTerm2 (`com.googlecode.iterm2`)

### 5.4 Preferences.swift — 偏好设置

通过 **App Group** (`group.com.macright.app`) 实现宿主 App 和扩展之间的数据共享：

```
宿主 App (SettingsView)                扩展 (FinderSync)
       │                                      │
       ▼                                      ▼
  Preferences.shared                    Preferences.shared
       │                                      │
       ▼                                      ▼
  UserDefaults(suiteName:              UserDefaults(suiteName:
    "group.com.macright.app")            "group.com.macright.app")
       │                                      │
       └──────────── 共享存储 ─────────────────┘
```

可配置项：
| Key | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| preferredTerminal | String | "Terminal" | 默认终端 App |
| enableDocx | Bool | true | 是否显示 Word 菜单项 |
| enableXlsx | Bool | true | 是否显示 Excel 菜单项 |
| enablePptx | Bool | true | 是否显示 PowerPoint 菜单项 |

---

## 6. App Bundle 结构

最终产物 `MacRight.app` 的内部结构：

```
MacRight.app/
└── Contents/
    ├── Info.plist                          # App 元数据
    ├── PkgInfo                            # 包类型标识 "APPL????"
    ├── MacOS/
    │   └── MacRight                       # 宿主 App 可执行文件
    ├── Resources/                         # (预留，当前为空)
    └── PlugIns/
        └── FinderSyncExtension.appex/     # Finder Sync 扩展
            └── Contents/
                ├── Info.plist             # 扩展元数据 (含 NSExtension 声明)
                ├── MacOS/
                │   └── FinderSyncExtension # 扩展可执行文件
                └── Resources/
                    └── Templates/
                        ├── blank.docx
                        ├── blank.xlsx
                        └── blank.pptx
```

### 6.1 关键 Info.plist 字段

**扩展 Info.plist 中的 NSExtension**：
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.FinderSync</string>          <!-- 扩展类型 -->
    <key>NSExtensionPrincipalClass</key>
    <string>FinderSyncExtension.FinderSync</string> <!-- 入口类 -->
</dict>
```

**扩展二进制类型**：
- 必须是 `Mach-O executable`（不是 bundle）
- 入口点使用 `_NSExtensionMain`（通过 `-Xlinker -e -Xlinker _NSExtensionMain` 指定）

---

## 7. 沙盒与权限模型

### 7.1 为什么需要沙盒

macOS Sequoia (15.x) 要求 Finder Sync Extension **必须声明 App Sandbox**，否则 `pluginkit` 拒绝注册：

```
rejecting; Ignoring mis-configured plugin: plug-ins must be sandboxed
```

### 7.2 权限声明 (Entitlements)

**扩展权限**：
```xml
com.apple.security.app-sandbox                    = true   <!-- 必须 -->
com.apple.security.files.user-selected.read-write = true   <!-- 用户选择的文件 -->
com.apple.security.files.home-relative-path.read-write = ["/"]  <!-- 主目录 -->
com.apple.security.files.downloads.read-write     = true   <!-- 下载目录 -->
com.apple.security.application-groups             = ["group.com.macright.app"]
```

### 7.3 权限限制

| 目录 | 能否创建文件 | 原因 |
|------|-------------|------|
| ~/Desktop | 可以 | 用户主目录子目录 |
| ~/Documents | 可以 | 用户主目录子目录 |
| ~/Downloads | 可以 | 用户主目录子目录 |
| ~/任意子目录 | 可以 | 用户主目录范围内 |
| /Users | 不可以 | 系统目录，非 root 无写入权限 |
| /Applications | 不可以 | 需要管理员权限 |
| 其他用户目录 | 不可以 | 无权限 |

> 注意：`temporary-exception` 类权限在 ad-hoc 签名下无效，需要正式 Developer ID 签名才生效。

---

## 8. 构建流程

### 8.1 构建脚本 (build.sh)

```
build.sh 执行流程：

1. 清理 build/ 目录
2. 创建 App Bundle 目录结构
3. swiftc 编译宿主 App → MacRight 可执行文件
4. swiftc 编译扩展 → FinderSyncExtension 可执行文件
   └── 特殊标志：-Xlinker -e -Xlinker _NSExtensionMain (入口点)
5. 复制模板文件到扩展 Resources
6. 生成 Info.plist (App + Extension)
7. Ad-hoc 代码签名 (带 entitlements)
8. 安装到 /Applications
9. 清理 build/ 中的扩展副本 (防止重复注册)
10. pluginkit 注册并启用扩展
11. 启动 App
```

### 8.2 为什么不用 xcodebuild

当前开发环境只有 Command Line Tools，没有完整 Xcode。`swiftc` 可以直接编译 Swift 代码并链接框架，`codesign` 处理签名。整个构建流程无需 Xcode。

---

## 9. 分发方案

### 9.1 当前方案 (Ad-hoc)

```
构建 → Ad-hoc 签名 → DMG 打包 → 直接分发
```

限制：用户首次打开时 macOS 会提示「无法验证开发者」，需右键选择「打开」。

### 9.2 正式发布方案

```
构建 → Developer ID 签名 → xcrun notarytool 公证 → xcrun stapler 装订 → DMG 打包
```

需要：
1. Apple Developer Program 账号 ($99/年)
2. Developer ID Application 证书
3. 公证通过后 macOS Gatekeeper 自动信任

---

## 10. 已知限制与踩坑记录

### 10.1 Finder Sync Extension 不支持子菜单

在 macOS Sequoia 上，Finder 会拆解扩展返回的 NSMenu，重新组装到自己的右键菜单中。这个过程中**子菜单 (submenu) 会丢失**或行为异常（点击父项直接关闭菜单）。

**结论**：只能使用扁平菜单结构。

### 10.2 菜单项 Action 不能设置 target

Finder Sync 扩展的菜单项通过 Finder 的 responder chain 分发 action，**不能** 设置 `item.target = self`，否则 action 不会被调用。

### 10.3 扩展必须沙盒化

macOS Sequoia 的 `pluginkit` 强制要求扩展声明 `com.apple.security.app-sandbox = true`，否则拒绝注册。

### 10.4 Ad-hoc 签名下 temporary-exception 无效

`com.apple.security.temporary-exception.*` 系列权限需要正式的 Team ID 签名才生效。Ad-hoc 签名时这些声明被忽略。

### 10.5 Bundle.main 在扩展中指向扩展自身

在 Finder Sync Extension 中，`Bundle.main` 指向 `.appex` Bundle，不是宿主 App。因此模板文件必须打包在扩展 Bundle 中。

### 10.6 build/ 和 /Applications 双副本导致菜单重复

LaunchServices 会同时发现两个位置的扩展，导致右键菜单项重复出现。解决方案：构建后删除 `build/` 中的 `.appex`。
