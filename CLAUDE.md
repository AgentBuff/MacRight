# CLAUDE.md — MacRight 项目指南

## 项目概述

MacRight 是一个 macOS Finder 右键菜单扩展应用，功能：
- 在当前目录新建 txt / docx / xlsx / pptx 文件
- 在当前目录打开终端（Terminal.app / iTerm2）

## 技术栈

- **语言**: Swift 5.9+，最低部署目标 macOS 13.0 (Ventura)
- **宿主 App UI**: SwiftUI
- **扩展 UI**: AppKit (NSMenu)，使用 Finder Sync Extension (`FIFinderSync`)
- **构建方式**: `swiftc` 命令行编译（不依赖 Xcode IDE），通过 `build.sh` 一键构建
- **无第三方依赖**

## 项目结构

```
MacRight/                  # 宿主 App（SwiftUI 设置界面）
FinderSyncExtension/       # Finder Sync 扩展（核心功能）
  ├── FinderSync.swift     # FIFinderSync 子类，菜单构建 + 事件路由
  ├── Actions/             # FileCreator.swift, TerminalLauncher.swift
  └── Resources/Templates/ # blank.docx/xlsx/pptx 空白模板
Shared/                    # 两个 Target 共享（Constants.swift, Preferences.swift）
Scripts/                   # create_templates.py（生成空白 Office 模板）
build.sh                   # 一键构建/签名/安装脚本
project.yml                # xcodegen 配置（可选，生成 .xcodeproj）
```

## 构建命令

```bash
# 一键构建、签名、安装到 /Applications 并启动
./build.sh

# 生成 Office 空白模板（首次或模板丢失时）
python3 Scripts/create_templates.py

# 生成 Xcode 项目（可选，需先 brew install xcodegen）
xcodegen generate
```

## 调试

```bash
# 查看扩展日志
log stream --predicate 'eventMessage CONTAINS "MacRight"'

# 检查扩展注册状态
pluginkit -m -p com.apple.FinderSync

# 强制重新注册
killall pkd && sleep 1 && pluginkit -e use -i com.macright.app.FinderSyncExtension
```

## 关键约束（踩坑记录）

1. **NSMenuItem 不要设置 target** — Finder Sync Extension 的菜单项必须依赖 responder chain 路由，设置 `item.target = self` 会导致点击无响应
2. **不要使用子菜单** — macOS Sequoia 上 Finder Sync 扩展的子菜单行为异常（父菜单提前消失），这是系统级限制
3. **扩展必须启用 App Sandbox** — `com.apple.security.app-sandbox = true`，否则 pluginkit 拒绝注册
4. **扩展入口点** — 编译扩展时必须指定 `-Xlinker -e -Xlinker _NSExtensionMain`，扩展没有自己的 main()
5. **避免 build/ 目录残留 .appex** — 会导致菜单项重复，build.sh 已处理
6. **onChange API** — 使用 macOS 13 兼容的 `onChange(of:) { newValue in }` 而非 macOS 14+ 的 `onChange(of:initial:_:)`
7. **文件写入权限** — 沙盒限制下，~/Desktop、~/Documents 等用户目录可写，/Users 等系统目录不可写，属正常行为

## 标识符

- Host App Bundle ID: `com.macright.app`
- Extension Bundle ID: `com.macright.app.FinderSyncExtension`
- App Group: `group.com.macright.app`

## 宿主 App ↔ 扩展通信

通过 App Group 共享 `UserDefaults(suiteName: "group.com.macright.app")` 传递偏好设置（终端选择、文件类型开关）。

## 代码规范

- 所有用户可见文本使用中文
- NSLog 前缀统一为 `"MacRight: "`
- 文件创建使用三级 fallback：Data.write → FileManager.createFile → /bin/cp
