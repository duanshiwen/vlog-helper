import SwiftUI
import VlogPackCore

/// 主工作台（v0.1 占位实现）
struct WorkspaceView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            TopBar()

            Divider()

            // 主内容区
            HSplitView {
                // 左侧：素材区（占位）
                MediaLibraryPlaceholder()
                    .frame(minWidth: 200, idealWidth: 250)

                // 中间：预览区（占位）
                VStack {
                    Image(systemName: "film")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                    Text("视频预览区")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 右侧：检查器（占位）
                InspectorPlaceholder()
                    .frame(minWidth: 200, idealWidth: 250)
            }

            // 底部：时间线（占位）
            TimelinePlaceholder()
                .frame(height: 160)
        }
    }
}

// MARK: - 顶栏

struct TopBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Button {
                appState.closeProject()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("返回启动页")

            Text(appState.currentProject?.projectName ?? "VlogPack")
                .font(.headline)

            Spacer()

            Text("粗剪 → 转写 → 校对 → 导出")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("导出") { }
                .disabled(true)
                .help("请先完成粗剪（v0.1-beta 可用）")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 素材区占位

struct MediaLibraryPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("素材库")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("拖入视频/图片素材")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 检查器占位

struct InspectorPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("检查器")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("字幕 / 封面 / 导出")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 时间线占位

struct TimelinePlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundStyle(.tertiary)
                Text("时间线：拖入素材后自动出现片段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Clip-based Timeline")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
