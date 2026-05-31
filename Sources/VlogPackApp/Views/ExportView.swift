import SwiftUI
import VlogPackCore

/// 导出视图
struct ExportView: View {
    @Environment(AppState.self) private var appState
    @State private var exportService = ExportService()
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var burnSubtitles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导出设置")
                .font(.headline)
                .padding(.horizontal, 10)

            // 规格信息
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "分辨率", value: "1920×1080")
                InfoRow(label: "比例", value: "16:9")
                InfoRow(label: "格式", value: "MP4 (H.264 + AAC)")
                InfoRow(label: "时间线", value: timelineInfo)
            }
            .padding(.horizontal, 10)

            Divider()

            // 导出选项
            VStack(alignment: .leading, spacing: 8) {
                Toggle("烧录字幕到视频", isOn: $burnSubtitles)
                    .font(.callout)

                Text("导出内容：")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Label("final.mp4", systemImage: "film")
                    if burnSubtitles {
                        Label("带字幕视频", systemImage: "captions.bubble")
                    }
                    Label("subtitles.srt", systemImage: "doc.text")
                    Label("subtitles.ass", systemImage: "doc.text")
                    Label("cover.jpg", systemImage: "photo")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)

            // 进度
            if isExporting {
                VStack(spacing: 4) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)
                    Text("导出中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
            }

            // 错误
            if let error = exportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
            }

            // 成功
            if exportSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("导出完成！")
                        .font(.callout)
                    Button("打开 exports/") {
                        openExportsFolder()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
            }

            Spacer()

            // 导出按钮
            HStack {
                Spacer()
                Button(action: startExport) {
                    HStack(spacing: 6) {
                        if isExporting {
                            ProgressView().controlSize(.mini)
                        }
                        Text(isExporting ? "导出中…" : "开始导出")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isExporting || !hasClips)
            }
            .padding(10)
        }
    }

    // MARK: - Helpers

    private var hasClips: Bool {
        !(appState.currentProject?.timeline.clips.isEmpty ?? true)
    }

    private var timelineInfo: String {
        guard let project = appState.currentProject else { return "—" }
        let clips = project.timeline.clips.count
        let duration = project.timeline.totalDuration
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(clips) 个片段, \(m):\(String(format: "%02d", s))"
    }

    private func startExport() {
        guard let project = appState.currentProject,
              let root = appState.currentProjectRoot else { return }

        isExporting = true
        exportError = nil
        exportSuccess = false
        exportProgress = 0

        // 捕获 actor-isolated 属性值
        let shouldBurnSubtitles = burnSubtitles
        let svc = exportService

        Task.detached {
            do {
                // 导出字幕文件
                svc.exportSubtitleFiles(project: project, projectRoot: root)

                if shouldBurnSubtitles {
                    _ = try svc.exportWithSubtitles(
                        project: project,
                        projectRoot: root,
                        onProgress: { time in
                            Task { @MainActor in
                                let total = project.timeline.totalDuration
                                exportProgress = total > 0 ? min(1.0, time / total) : 0
                            }
                        }
                    )
                } else {
                    _ = try svc.exportNoSubtitle(
                        project: project,
                        projectRoot: root,
                        onProgress: { time in
                            Task { @MainActor in
                                let total = project.timeline.totalDuration
                                exportProgress = total > 0 ? min(1.0, time / total) : 0
                            }
                        }
                    )
                }

                // 导出封面
                let coverService = CoverService()
                try? coverService.exportCover(project: project, projectRoot: root)

                await MainActor.run {
                    isExporting = false
                    exportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = "导出失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func openExportsFolder() {
        guard let root = appState.currentProjectRoot else { return }
        let exportsDir = root.appendingPathComponent("exports")
        NSWorkspace.shared.open(exportsDir)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.caption)
            Spacer()
        }
    }
}
