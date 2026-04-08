import SwiftUI
import FinderSync

struct ContentView: View {
    @State private var extensionEnabled = false

    var body: some View {
        VStack(spacing: 24) {
            // App Icon area
            Image(systemName: "contextualmenu.and.cursorarrow")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("MacRight")
                .font(.largeTitle.bold())

            Text("Finder 右键菜单增强工具")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            // Extension status
            HStack(spacing: 12) {
                Image(systemName: extensionEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(extensionEnabled ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展未启用")
                        .font(.headline)
                    Text(extensionEnabled ? "右键菜单功能已就绪" : "请在系统设置中启用扩展")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(extensionEnabled ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            )

            if !extensionEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如何启用：")
                        .font(.headline)

                    StepView(number: 1, text: "点击下方按钮打开系统设置")
                    StepView(number: 2, text: "通用 → 登录项与扩展 → 已添加的扩展")
                    StepView(number: 3, text: "找到 MacRight，启用 Finder 扩展")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.05))
                )

                Button("打开系统设置 - 扩展") {
                    openExtensionSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 8) {
                Text("功能")
                    .font(.headline)

                FeatureRow(icon: "doc.badge.plus", title: "新建 Office 文件", description: "右键创建 Word、Excel、PowerPoint")
                FeatureRow(icon: "terminal", title: "在此打开终端", description: "在当前目录打开 Terminal 或 iTerm")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.05))
            )

            Spacer()
        }
        .padding(30)
        .frame(width: 480, height: 620)
        .onAppear {
            checkExtensionStatus()
        }
    }

    private func checkExtensionStatus() {
        // Check if our extension is enabled via pluginkit
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-p", "com.apple.FinderSync"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            extensionEnabled = output.contains(AppConstants.extensionBundleID)
        } catch {
            extensionEnabled = false
        }
    }

    private func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct StepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))
                .foregroundStyle(.white)
            Text(text)
                .font(.body)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(title).font(.body.bold())
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
