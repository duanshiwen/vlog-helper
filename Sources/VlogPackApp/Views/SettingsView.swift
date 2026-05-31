import SwiftUI
import VlogPackCore

/// 应用设置
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var setupService = SetupService()
    @State private var ffmpegStatus: ToolLocator.ToolStatus?
    @State private var whisperStatus: ToolLocator.ToolStatus?
    @State private var defaultExportDir: String = ""

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            ToolsTab()
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver")
                }

            TemplatesTab()
                .tabItem {
                    Label("模板", systemImage: "doc.on.doc")
                }
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - General

struct GeneralTab: View {
    @State private var defaultProjectDir: String = ""

    var body: some View {
        Form {
            Section("默认项目目录") {
                HStack {
                    TextField("", text: $defaultProjectDir)
                        .textFieldStyle(.roundedBorder)
                    Button("选择…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            defaultProjectDir = url.path
                        }
                    }
                }
            }

            Section("默认设置") {
                Text("默认比例：16:9 横屏")
                    .foregroundStyle(.secondary)
                Text("默认分辨率：1920×1080")
                    .foregroundStyle(.secondary)
                Text("导出格式：MP4 (H.264 + AAC)")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Tools

struct ToolsTab: View {
    @State private var ffmpegPath: String = ""
    @State private var whisperPath: String = ""

    var body: some View {
        Form {
            Section("FFmpeg") {
                HStack {
                    Text("路径：")
                        .frame(width: 60, alignment: .trailing)
                    TextField("", text: $ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                    Button("检测") {
                        ffmpegPath = ToolLocator.ffmpegPath()
                    }
                    .controlSize(.small)
                }
                HStack {
                    Text("状态：")
                        .frame(width: 60, alignment: .trailing)
                    if FFmpegAdapter().checkAvailability() {
                        Label("可用", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("未找到", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("whisper.cpp") {
                HStack {
                    Text("路径：")
                        .frame(width: 60, alignment: .trailing)
                    TextField("", text: $whisperPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                    Button("检测") {
                        whisperPath = ToolLocator.whisperPath()
                    }
                    .controlSize(.small)
                }
                HStack {
                    Text("状态：")
                        .frame(width: 60, alignment: .trailing)
                    if WhisperAdapter().checkAvailability() {
                        Label("可用", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("未安装（可选）", systemImage: "minus.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            ffmpegPath = ToolLocator.ffmpegPath()
            whisperPath = ToolLocator.whisperPath()
        }
    }
}

// MARK: - Templates

struct TemplatesTab: View {
    @State private var templateService = TemplateService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("内置模板")
                .font(.headline)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("字幕模板")
                        .font(.callout.bold())
                    ForEach(Array(templateService.builtinSubtitleTemplates.keys.sorted()), id: \.self) { name in
                        Label(name, systemImage: "text.bubble")
                            .font(.callout)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("封面模板")
                        .font(.callout.bold())
                    ForEach(Array(templateService.builtinCoverTemplates.keys.sorted()), id: \.self) { name in
                        Label(name, systemImage: "photo")
                            .font(.callout)
                    }
                }
            }

            Spacer()

            Text("自定义模板保存在：~/.vlogpack/templates/")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
