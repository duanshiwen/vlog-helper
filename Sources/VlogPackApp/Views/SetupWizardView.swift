import SwiftUI
import VlogPackCore

/// 首次启动设置向导
struct SetupWizardView: View {
    @Environment(AppState.self) private var appState
    @State private var setupService = SetupService()
    @State private var toolStatuses: [ToolLocator.ToolStatus] = []
    @State private var isChecking = true
    @State private var ffmpegInstalled = false
    @State private var whisperInstalled = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "video.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("欢迎使用 VlogPack")
                    .font(.title.bold())

                Text("VlogPack 是一款本地 Vlog 日更工作台，使用前需要一些外部工具。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)

            // Tool Status Cards
            VStack(spacing: 16) {
                ToolCard(
                    icon: "film",
                    name: "FFmpeg",
                    description: "视频处理引擎，用于拼接、裁剪、导出视频",
                    isRequired: true,
                    status: ffmpegStatus
                )

                ToolCard(
                    icon: "waveform",
                    name: "whisper.cpp",
                    description: "语音转文字引擎，用于自动生成字幕",
                    isRequired: false,
                    status: whisperStatus
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                if !ffmpegInstalled {
                    Button {
                        installFFmpeg()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                            Text("安装 FFmpeg（通过 Homebrew）")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("需要先安装 Homebrew：https://brew.sh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("重新检测") {
                        refreshStatus()
                    }
                    .controlSize(.regular)

                    Button("跳过，直接开始") {
                        setupService.markSetupComplete()
                        appState.needsSetup = false
                    }
                    .controlSize(.regular)
                    .disabled(!ffmpegInstalled) // FFmpeg 是必须的
                }
            }
            .padding(.bottom, 40)
        }
        .frame(width: 580, height: 520)
        .onAppear {
            refreshStatus()
        }
    }

    // MARK: - Status

    private var ffmpegStatus: ToolStatus {
        ffmpegInstalled ? .ready : .missing
    }

    private var whisperStatus: ToolStatus {
        whisperInstalled ? .ready : .notRequired
    }

    private func refreshStatus() {
        isChecking = true
        Task.detached {
            let statuses = ToolLocator.checkAll()
            let ffmpegOK = statuses.contains { ($0.name == "ffmpeg" || $0.name == "ffprobe") && $0.found }
            let whisperOK = statuses.contains { $0.name == "whisper" && $0.found }

            await MainActor.run {
                toolStatuses = statuses
                ffmpegInstalled = ffmpegOK
                whisperInstalled = whisperOK
                isChecking = false

                if ffmpegOK {
                    _ = setupService.refreshToolStatus()
                }
            }
        }
    }

    private func installFFmpeg() {
        // 打开终端执行安装命令
        let script = """
        tell application "Terminal"
            activate
            do script "brew install ffmpeg"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }

        // 提示用户安装后点击重新检测
    }
}

// MARK: - Tool Status Enum

enum ToolStatus {
    case ready
    case missing
    case notRequired
}

// MARK: - Tool Card

struct ToolCard: View {
    let icon: String
    let name: String
    let description: String
    let isRequired: Bool
    let status: ToolStatus

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.headline)
                    if isRequired {
                        Text("必需")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("可选")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray)
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status
            statusBadge
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .ready:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("就绪")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
        case .missing:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("未安装")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        case .notRequired:
            HStack(spacing: 4) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.gray)
                Text("可选")
                    .font(.callout)
                    .foregroundStyle(.gray)
            }
        }
    }

    private var iconColor: Color {
        switch status {
        case .ready: return .green
        case .missing: return .red
        case .notRequired: return .gray
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.1)
    }

    private var borderColor: Color {
        switch status {
        case .ready: return .green.opacity(0.3)
        case .missing: return .red.opacity(0.3)
        case .notRequired: return .gray.opacity(0.2)
        }
    }
}
