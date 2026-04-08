import SwiftUI

struct SettingsView: View {
    @State private var preferredTerminal: TerminalApp = Preferences.shared.preferredTerminal
    @State private var enableDocx: Bool = Preferences.shared.enableDocx
    @State private var enableXlsx: Bool = Preferences.shared.enableXlsx
    @State private var enablePptx: Bool = Preferences.shared.enablePptx

    var body: some View {
        Form {
            Section("终端设置") {
                Picker("默认终端", selection: $preferredTerminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.displayName).tag(app)
                    }
                }
                .onChange(of: preferredTerminal) { newValue in
                    Preferences.shared.preferredTerminal = newValue
                }
            }

            Section("文件类型") {
                Toggle("Word 文档 (.docx)", isOn: $enableDocx)
                    .onChange(of: enableDocx) { newValue in
                        Preferences.shared.enableDocx = newValue
                    }

                Toggle("Excel 表格 (.xlsx)", isOn: $enableXlsx)
                    .onChange(of: enableXlsx) { newValue in
                        Preferences.shared.enableXlsx = newValue
                    }

                Toggle("PowerPoint 演示 (.pptx)", isOn: $enablePptx)
                    .onChange(of: enablePptx) { newValue in
                        Preferences.shared.enablePptx = newValue
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }
}
