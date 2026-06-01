import SwiftUI
import VlogPackCore

/// 主工作台
struct WorkspaceView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            TopBar()

            Divider()

            // 主工作区：左右、上下均可拖动调整大小
            VSplitView {
                HSplitView {
                    // 左侧：素材库
                    MediaLibraryView()
                        .frame(minWidth: 180, idealWidth: 260, maxWidth: .infinity)

                    // 中间：预览播放器
                    PreviewPlayerView()
                        .frame(minWidth: 320, idealWidth: 680, maxWidth: .infinity)

                    // 右侧：检查器
                    InspectorPanelView()
                        .frame(minWidth: 260, idealWidth: 340, maxWidth: .infinity)
                }
                .frame(minHeight: 320, idealHeight: 520, maxHeight: .infinity)

                // 底部：时间线
                TimelineView()
                    .frame(minHeight: 120, idealHeight: 180, maxHeight: 360)
            }
        }
    }
}

// MARK: - 顶栏

struct TopBar: View {
    @Environment(AppState.self) private var appState
    @State private var showSaveStatus = false

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

            Text("素材 → 粗剪 → 字幕 → 封面 → 导出")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if showSaveStatus {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("已保存")
                        .font(.caption)
                }
                .transition(.opacity)
            }

            Button {
                saveProject()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .help("保存项目")
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func saveProject() {
        try? appState.saveCurrentProject()
        withAnimation {
            showSaveStatus = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveStatus = false
            }
        }
    }
}
