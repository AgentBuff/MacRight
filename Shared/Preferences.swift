import Foundation

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        }
    }

    var displayName: String { rawValue }
}

final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    var preferredTerminal: TerminalApp {
        get {
            let raw = defaults.string(forKey: "preferredTerminal") ?? TerminalApp.terminal.rawValue
            return TerminalApp(rawValue: raw) ?? .terminal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "preferredTerminal")
        }
    }

    var enableDocx: Bool {
        get { defaults.object(forKey: "enableDocx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableDocx") }
    }

    var enableXlsx: Bool {
        get { defaults.object(forKey: "enableXlsx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableXlsx") }
    }

    var enablePptx: Bool {
        get { defaults.object(forKey: "enablePptx") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enablePptx") }
    }
}
