import Foundation
import AppKit

final class TerminalLauncher {

    static func open(at directory: URL, using app: TerminalApp) {
        let bundleID = app.bundleIdentifier
        let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)

        guard let appURL = appURL else {
            NSLog("MacRight: \(app.displayName) not found")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = []

        // For Terminal.app, opening a folder URL directly opens a new window cd'd to that path
        // For iTerm, we pass the directory as an argument
        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: appURL,
            configuration: config
        ) { app, error in
            if let error = error {
                NSLog("MacRight: Failed to open terminal: \(error.localizedDescription)")
            }
        }
    }
}
