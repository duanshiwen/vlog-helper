import SwiftUI
import VlogPackCore

struct NewProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var parentURL: URL? = nil
    @State private var errorMessage: String?

    /// 预览文件夹名
    private var previewFolderName: String {
        guard !projectName.isEmpty else { return "—" }
        return FileNameGenerator.projectFolderName(projectName: projectName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("新建项目")
                .font(.title2.weight(.semibold))

            // 项目名
            VStack(alignment: .leading, spacing: 4) {
                Text("项目名称")
                    .font(.headline)
                TextField("例如：杭州日更 Vlog", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                Text("文件夹名：\(previewFolderName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 保存目录
            VStack(alignment: .leading, spacing: 4) {
                Text("保存位置")
                    .font(.headline)
                HStack {
                    Text(parentURL?.path ?? "未选择")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(parentURL == nil ? .secondary : .primary)
                    Spacer()
                    Button("选择…") {
                        selectFolder()
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }

            // 错误
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("创建项目") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(projectName.isEmpty || parentURL == nil)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择项目保存目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        parentURL = url
    }

    private func createProject() {
        guard let parentURL else { return }
        do {
            try appState.createProject(
                name: projectName.trimmingCharacters(in: .whitespaces),
                parentURL: parentURL
            )
            dismiss()
        } catch {
            errorMessage = "创建项目失败：\(error.localizedDescription)"
        }
    }
}
