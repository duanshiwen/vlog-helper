import SwiftUI
import VlogPackCore

struct LaunchView: View {
    @Environment(AppState.self) private var appState
    @State private var showNewProject = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            // Logo / Title
            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("VlogPack")
                    .font(.largeTitle.weight(.bold))
                Text("本地日更 Vlog 工作台")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Actions
            VStack(spacing: 12) {
                Button("新建项目") {
                    showNewProject = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("打开项目…") {
                    openProjectPanel()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            Divider()

            // Recent projects
            if !appState.recentProjects.all.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近项目")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    ForEach(appState.recentProjects.all.prefix(10)) { entry in
                        RecentProjectRow(entry: entry) {
                            openRecent(entry)
                        }
                    }
                }
                .frame(maxWidth: 400)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
        }
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择项目目录"
        panel.message = "选择一个 VlogPack 项目文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try appState.openProject(at: url)
        } catch {
            errorMessage = "打开项目失败：\(error.localizedDescription)"
        }
    }

    private func openRecent(_ entry: RecentProjectEntry) {
        guard entry.isOpenable else {
            errorMessage = "项目目录不存在：\(entry.projectRootPath)"
            return
        }
        do {
            try appState.openProject(at: URL(fileURLWithPath: entry.projectRootPath))
        } catch {
            errorMessage = "打开项目失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 最近项目行

struct RecentProjectRow: View {
    let entry: RecentProjectEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: entry.isOpenable ? "folder.fill" : "folder.badge.questionmark")
                    .foregroundStyle(entry.isOpenable ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.projectName)
                        .font(.body)
                        .lineLimit(1)
                    Text(entry.projectRootPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(entry.lastOpenedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
