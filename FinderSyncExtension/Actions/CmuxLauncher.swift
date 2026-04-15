import Foundation
import AppKit

final class CmuxLauncher {

    static let bundleIdentifier = "com.cmuxterm.app"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static func open(at directory: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            NSLog("MacRight: cmux not found")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = []

        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if let error = error {
                NSLog("MacRight: Failed to open cmux: \(error.localizedDescription)")
            }
        }
    }
}
