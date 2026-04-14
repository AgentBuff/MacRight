# MacRight

> 扩展 macOS Finder 右键菜单，快速新建文件、打开终端。

[English](README.md)

---

macOS 的 Finder 一直缺少"新建文件"的右键菜单选项——这在 Windows 上是最基本的功能。**MacRight** 通过轻量级的 Finder Sync Extension 填补了这一空白。

## 功能

- **新建文本文件** — 在当前目录创建空白 `.txt` 文件
- **新建 Word 文档** — 在当前目录创建空白 `.docx` 文件
- **新建 Excel 表格** — 在当前目录创建空白 `.xlsx` 文件
- **新建 PowerPoint 演示** — 在当前目录创建空白 `.pptx` 文件
- **在此打开终端** — 在当前目录启动 Terminal.app 或 iTerm2

所有菜单项直接出现在 Finder 右键菜单中，无需额外点击。

## 截图

<!-- 在此添加截图 -->
<!-- ![右键菜单](docs/screenshots/context-menu.png) -->
<!-- ![宿主应用](docs/screenshots/host-app.png) -->

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Apple Silicon 或 Intel Mac

## 安装

### 方式一：下载 DMG

从 [Releases](../../releases) 下载最新的 `.dmg` 文件，打开后将 **MacRight.app** 拖入 `/Applications`。

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/AgentBuff/mac-right.git
cd mac-right

# 生成空白 Office 模板文件
python3 Scripts/create_templates.py

# 一键构建、签名、安装并启动
./build.sh
```

> 只需安装 Xcode Command Line Tools（`xcode-select --install`），不需要完整的 Xcode。

### 启用扩展

安装完成后，需要手动启用 Finder 扩展：

1. 打开 **系统设置**
2. 进入 **通用** → **登录项与扩展**
3. 点击 **已添加的扩展**
4. 找到 **MacRight**，启用 **Finder 扩展**

也可以打开 MacRight.app，点击"打开系统设置 - 扩展"按钮直达设置页面。

## 使用方法

1. 在任意 Finder 窗口中右键（或 Control + 点击）
2. 在右键菜单中可以看到 MacRight 的菜单项
3. 点击即可创建文件或打开终端

创建文件时自动处理重名冲突：
`未命名文档.docx` → `未命名文档 2.docx` → `未命名文档 3.docx`

## 设置

打开 MacRight.app，按 **Cmd + ,** 进入设置：

- **终端选择** — Terminal.app 或 iTerm2
- **文件类型** — 选择在右键菜单中显示哪些文件类型（Word、Excel、PowerPoint）

设置通过 App Group 共享 UserDefaults 在宿主 App 和扩展之间同步。

## 架构

```
MacRight.app（宿主 App — SwiftUI 设置界面）
└── Contents/PlugIns/
    └── FinderSyncExtension.appex（Finder Sync 扩展 — 右键菜单功能）
```

- **宿主 App**：显示扩展状态、提供设置界面、引导用户启用扩展
- **扩展**：通过 `FIFinderSync` 向 Finder 注册、构建右键菜单、处理文件创建和终端启动
- **通信方式**：App Group 共享 `UserDefaults`（`group.com.macright.app`）

详细架构设计请参阅 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 技术栈

| 组件 | 技术方案 |
|------|----------|
| 语言 | Swift 5.9+ |
| 宿主 App UI | SwiftUI |
| 扩展 | FinderSync 框架 (AppKit) |
| 构建 | `swiftc` 命令行 + Shell 脚本（无需 Xcode） |
| 文件模板 | 最小化 Office Open XML（基于 ZIP） |
| 第三方依赖 | 无（纯 Apple 原生框架） |

## 开发

查看完整的 [开发手册](docs/DEVELOPMENT.md) 了解：

- 环境搭建
- 构建系统详解
- 调试技巧
- 如何添加新文件类型或菜单项
- App Sandbox 与权限
- 打包与分发

### 快速上手

```bash
# 构建并安装
./build.sh

# 查看扩展日志
log stream --predicate 'eventMessage CONTAINS "MacRight"'

# 检查扩展注册状态
pluginkit -m -p com.apple.FinderSync
```

## 已知限制

- **不支持子菜单** — macOS Sequoia 存在系统级问题，Finder Sync Extension 的子菜单在展开前会消失。因此所有菜单项采用扁平布局。
- **系统目录** — 沙盒限制下无法在 `/Users`、`/Applications` 等系统目录创建文件，这是 macOS 的正常行为。
- **Ad-hoc 签名** — 没有 Developer ID 签名时，其他用户首次打开需右键 → 打开来绕过 Gatekeeper。

## 许可证

[MIT](LICENSE)

## 致谢

使用 Swift 和 Apple FinderSync 框架构建，无任何第三方依赖。
