import SwiftUI
import VlogPackCore

/// 项目信息视图
struct ProjectInfoView: View {
    @Environment(AppState.self) private var appState
    @State private var projectService = ProjectService()
    @State private var integrityStatus: String?
    @State private var projectSize: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("项目信息")
                .font(.headline)
                .padding(.horizontal, 10)

            if let project = appState.currentProject,
               let root = appState.currentProjectRoot {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "名称", value: project.projectName)
                    InfoRow(label: "ID", value: project.projectId)
                    InfoRow(label: "格式版本", value: project.schemaVersion)
                    InfoRow(label: "比例", value: project.aspectRatio.rawValue)
                    InfoRow(label: "分辨率", value: "\(project.resolution.width)×\(project.resolution.height)")
                    InfoRow(label: "素材", value: "\(project.mediaItems.count) 个")
                    InfoRow(label: "片段", value: "\(project.timeline.clips.count) 个")
                    InfoRow(label: "字幕", value: "\(project.subtitles?.segments.count ?? 0) 条")

                    if let size = projectSize {
                        InfoRow(label: "大小", value: size)
                    }
                }
                .padding(.horizontal, 10)

                Divider()

                // 目录
                VStack(alignment: .leading, spacing: 4) {
                    Text("项目目录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(root.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)

                // 完整性检查
                HStack {
                    Button("检查完整性") {
                        checkIntegrity()
                    }
                    .controlSize(.small)

                    Button("修复缺失目录") {
                        repairProject()
                    }
                    .controlSize(.small)

                    if let status = integrityStatus {
                        Text(status)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 10)

                // 操作
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.open(root)
                    }
                    .controlSize(.small)

                    Button("打开项目目录") {
                        NSWorkspace.shared.open(root)
                    }
                    .controlSize(.small)

                    Button("清除缓存") {
                        clearCache()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)

                Spacer()

                // 关闭项目
                HStack {
                    Spacer()
                    Button("关闭项目") {
                        appState.closeProject()
                    }
                    .controlSize(.small)
                }
                .padding(10)
            }
        }
        .onAppear {
            calculateSize()
        }
    }

    // MARK: - Actions

    private func checkIntegrity() {
        guard let root = appState.currentProjectRoot else { return }
        let missing = projectService.checkIntegrity(projectRoot: root)
        if missing.isEmpty {
            integrityStatus = "✅ 项目完整"
        } else {
            integrityStatus = "⚠️ 缺失 \(missing.count) 个目录"
        }
    }

    private func repairProject() {
        guard let root = appState.currentProjectRoot else { return }
        do {
            try projectService.repairProject(projectRoot: root)
            integrityStatus = "✅ 已修复"
        } catch {
            integrityStatus = "❌ 修复失败"
        }
    }

    private func clearCache() {
        guard let root = appState.currentProjectRoot else { return }
        let cacheDir = root.appendingPathComponent("cache")
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for item in contents {
                // 保留 waveforms
                if item.lastPathComponent == "waveforms" { continue }
                try? fm.removeItem(at: item)
                // 重建空目录
                try? fm.createDirectory(at: item, withIntermediateDirectories: true)
            }
        }
    }

    private func calculateSize() {
        guard let root = appState.currentProjectRoot else { return }
        Task.detached {
            let size = Self.calculateDirectorySize(root)
            let formatted = ByteCountFormatter.string(
                fromByteCount: Int64(size),
                countStyle: .file
            )
            await MainActor.run {
                projectSize = formatted
            }
        }
    }

    nonisolated private static func calculateDirectorySize(_ url: URL) -> UInt64 {
        let fm = FileManager.default
        var size: UInt64 = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
               let fileSize = attrs[.size] as? UInt64 {
                size += fileSize
            }
        }
        return size
    }
}
