# MacRight

> Extend macOS Finder right-click menu with quick file creation and terminal access.

[中文文档](README_CN.md)

---

macOS has long lacked a built-in "New File" option in Finder's context menu — something Windows users take for granted. **MacRight** fills this gap with a lightweight Finder Sync Extension.

## Features

- **New Text File** — Create an empty `.txt` file in the current directory
- **New Word Document** — Create a blank `.docx` file
- **New Excel Spreadsheet** — Create a blank `.xlsx` file
- **New PowerPoint Presentation** — Create a blank `.pptx` file
- **Open Terminal Here** — Launch Terminal.app or iTerm2 at the current directory

All menu items appear directly in Finder's right-click context menu — no extra clicks needed.

## Screenshots

<!-- Add screenshots here -->
<!-- ![Right-click Menu](docs/screenshots/context-menu.png) -->
<!-- ![Host App](docs/screenshots/host-app.png) -->

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Option 1: Download DMG

Download the latest `.dmg` from [Releases](../../releases), open it, and drag **MacRight.app** to `/Applications`.

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/user/mac-right.git
cd mac-right

# Generate blank Office templates
python3 Scripts/create_templates.py

# Build, sign, install, and launch
./build.sh
```

> Only Xcode Command Line Tools are required (`xcode-select --install`). Full Xcode is optional.

### Enable the Extension

After installation, you need to manually enable the Finder extension:

1. Open **System Settings**
2. Go to **General** → **Login Items & Extensions**
3. Click **Added Extensions**
4. Find **MacRight** and enable the **Finder Extension**

Or launch MacRight.app and click the "Open System Settings" button.

## Usage

1. Right-click (or Control-click) in any Finder window
2. You'll see MacRight's menu items in the context menu
3. Click to create a file or open terminal

Created files use auto-incrementing names to avoid conflicts:
`Untitled.docx` → `Untitled 2.docx` → `Untitled 3.docx`

## Configuration

Open MacRight.app and go to **Settings** (Cmd + ,):

- **Terminal**: Choose between Terminal.app and iTerm2
- **File Types**: Toggle which file types appear in the context menu (Word, Excel, PowerPoint)

Settings sync between the host app and extension via App Group shared UserDefaults.

## Architecture

```
MacRight.app (Host App — SwiftUI settings UI)
└── Contents/PlugIns/
    └── FinderSyncExtension.appex (Finder Sync Extension — context menu)
```

- **Host App**: Displays extension status, provides settings UI, guides users to enable the extension
- **Extension**: Registers with Finder via `FIFinderSync`, builds context menu, handles file creation and terminal launching
- **Communication**: App Group shared `UserDefaults` (`group.com.macright.app`)

For detailed architecture, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| Host App UI | SwiftUI |
| Extension | FinderSync framework (AppKit) |
| Build | `swiftc` CLI + shell script (no Xcode required) |
| File Templates | Minimal Office Open XML (ZIP-based) |
| Dependencies | None (pure Apple frameworks) |

## Development

See the full [Development Guide](docs/DEVELOPMENT.md) for:

- Environment setup
- Build system details
- Debugging techniques
- How to add new file types or menu items
- App Sandbox & entitlements
- Packaging & distribution

### Quick Start

```bash
# Build and install
./build.sh

# View extension logs
log stream --predicate 'eventMessage CONTAINS "MacRight"'

# Check extension registration
pluginkit -m -p com.apple.FinderSync
```

## Known Limitations

- **Submenus not supported** — macOS Sequoia has a bug where Finder Sync Extension submenus dismiss prematurely. All items use a flat menu layout.
- **System directories** — Sandbox restrictions prevent file creation in system directories like `/Users` or `/Applications`. This is expected macOS behavior.
- **Ad-hoc signing** — Without a Developer ID, other users need to right-click → Open to bypass Gatekeeper on first launch.

## License

[MIT](LICENSE)

## Acknowledgments

Built with Swift and Apple's FinderSync framework. No third-party dependencies.
