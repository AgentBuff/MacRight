import Cocoa
import FinderSync
import UniformTypeIdentifiers

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let prefs = Preferences.shared

        menu.addItem(NSMenuItem(title: "新建文本文件", action: #selector(createTxt(_:)), keyEquivalent: ""))
        if prefs.enableDocx {
            menu.addItem(NSMenuItem(title: "新建 Word 文档", action: #selector(createDocx(_:)), keyEquivalent: ""))
        }
        if prefs.enableXlsx {
            menu.addItem(NSMenuItem(title: "新建 Excel 表格", action: #selector(createXlsx(_:)), keyEquivalent: ""))
        }
        if prefs.enablePptx {
            menu.addItem(NSMenuItem(title: "新建 PowerPoint 演示", action: #selector(createPptx(_:)), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "在此打开终端", action: #selector(openTerminal(_:)), keyEquivalent: ""))

        return menu
    }

    // MARK: - Target Directory

    private var targetDirectory: URL? {
        // targetedURL() returns the directory shown in the current Finder window
        let targeted = FIFinderSyncController.default().targetedURL()
        NSLog("MacRight: targetedURL = \(targeted?.path ?? "nil")")

        // If user right-clicked on a folder, use that folder
        if let items = FIFinderSyncController.default().selectedItemURLs() {
            NSLog("MacRight: selectedItems = \(items.map { $0.path })")
            for item in items {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    return item
                }
            }
        }
        return targeted
    }

    // MARK: - Actions

    @objc func createTxt(_ sender: AnyObject?) {
        NSLog("MacRight: createTxt called!")
        guard let dir = targetDirectory else { NSLog("MacRight: no target dir"); return }
        FileCreator.createFile(type: .txt, in: dir)
    }

    @objc func createDocx(_ sender: AnyObject?) {
        NSLog("MacRight: createDocx called!")
        guard let dir = targetDirectory else { NSLog("MacRight: no target dir"); return }
        FileCreator.createFile(type: .docx, in: dir)
    }

    @objc func createXlsx(_ sender: AnyObject?) {
        NSLog("MacRight: createXlsx called!")
        guard let dir = targetDirectory else { NSLog("MacRight: no target dir"); return }
        FileCreator.createFile(type: .xlsx, in: dir)
    }

    @objc func createPptx(_ sender: AnyObject?) {
        NSLog("MacRight: createPptx called!")
        guard let dir = targetDirectory else { NSLog("MacRight: no target dir"); return }
        FileCreator.createFile(type: .pptx, in: dir)
    }

    @objc func openTerminal(_ sender: AnyObject?) {
        NSLog("MacRight: openTerminal called!")
        guard let dir = targetDirectory else { NSLog("MacRight: no target dir"); return }
        TerminalLauncher.open(at: dir, using: Preferences.shared.preferredTerminal)
    }
}
