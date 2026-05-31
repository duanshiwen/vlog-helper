import SwiftUI
import VlogPackCore

/// 封面编辑器视图
struct CoverEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var coverService = CoverService()
    @State private var templateService = TemplateService()
    @State private var isGenerating = false
    @State private var candidates: [String] = []
    @State private var selectedCandidate: String?

    private var cover: CoverDesign? {
        appState.currentProject?.cover
    }

    private var title: Binding<String> {
        Binding(
            get: { appState.currentProject?.cover?.title ?? "" },
            set: {
                coverService.updateTitle($0, project: &appState.currentProject!)
                try? appState.saveCurrentProject()
            }
        )
    }

    private var textStyle: Binding<CoverTextStyle> {
        Binding(
            get: { appState.currentProject?.cover?.textStyle ?? CoverTextStyle() },
            set: {
                coverService.updateTextStyle($0, project: &appState.currentProject!)
                try? appState.saveCurrentProject()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 生成候选帧
            HStack {
                Button {
                    generateCandidates()
                } label: {
                    HStack(spacing: 4) {
                        if isGenerating { ProgressView().controlSize(.mini) }
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(isGenerating ? "生成中…" : "视频抽帧")
                    }
                }
                .disabled(isGenerating || !hasClips)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("导入图片…") {
                    importCoverImage()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 10)

            // 候选帧列表
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("候选封面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)

                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(candidates, id: \.self) { path in
                                CandidateFrame(
                                    path: path,
                                    projectRoot: appState.currentProjectRoot!,
                                    isSelected: selectedCandidate == path
                                )
                                .onTapGesture {
                                    selectedCandidate = path
                                    coverService.selectCandidate(
                                        candidatePath: path,
                                        project: &appState.currentProject!
                                    )
                                    try? appState.saveCurrentProject()
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                Divider()
            }

            // 标题
            VStack(alignment: .leading, spacing: 6) {
                Text("封面标题").font(.caption).foregroundStyle(.secondary)
                TextField("输入封面标题", text: title)
                    .textFieldStyle(.roundedBorder)

                // 标题样式
                HStack {
                    Text("字体").font(.caption).frame(width: 50, alignment: .trailing)
                    TextField("", text: textStyle.fontFamily)
                        .textFieldStyle(.roundedBorder).font(.caption)
                }
                HStack {
                    Text("字号").font(.caption).frame(width: 50, alignment: .trailing)
                    Slider(value: textStyle.fontSize, in: 24...128, step: 4)
                    Text("\(Int(textStyle.fontSize.wrappedValue))")
                        .font(.caption.monospacedDigit()).frame(width: 30)
                }
                HStack {
                    Text("文字色").font(.caption).frame(width: 50, alignment: .trailing)
                    ColorField(hex: textStyle.textColor)
                    Text("描边色").font(.caption)
                    ColorField(hex: textStyle.outlineColor)
                }
                HStack {
                    Text("描边").font(.caption).frame(width: 50, alignment: .trailing)
                    Slider(value: textStyle.outlineWidth, in: 0...10, step: 0.5)
                    Text(String(format: "%.1f", textStyle.outlineWidth.wrappedValue))
                        .font(.caption.monospacedDigit()).frame(width: 30)
                }
            }
            .padding(.horizontal, 10)

            // 模板
            HStack {
                Text("模板：").font(.caption)
                ForEach(Array(templateService.builtinCoverTemplates.keys.sorted()), id: \.self) { name in
                    Button(name) {
                        if let tmpl = templateService.builtinCoverTemplates[name] {
                            templateService.applyCoverTemplate(tmpl, project: &appState.currentProject!)
                            try? appState.saveCurrentProject()
                        }
                    }
                    .controlSize(.mini)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 10)

            // Logo
            HStack {
                Button("导入 Logo…") { importLogo() }
                    .controlSize(.small)
                if appState.currentProject?.cover?.logoPath != nil {
                    Text("✓ Logo 已设置")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // 导出封面
            HStack {
                Spacer()
                Button("导出封面") {
                    exportCover()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(10)
        }
    }

    // MARK: - Actions

    private var hasClips: Bool {
        !(appState.currentProject?.timeline.clips.isEmpty ?? true)
    }

    private func generateCandidates() {
        guard let root = appState.currentProjectRoot,
              appState.currentProject != nil else { return }
        isGenerating = true
        let svc = coverService
        Task {
            do {
                let paths = try svc.generateCandidates(
                    project: appState.currentProject!,
                    projectRoot: root
                )
                candidates = paths
            } catch {
                VlogPackLog.error("Generate candidates failed: \(error)")
            }
            isGenerating = false
        }
    }

    private func importCoverImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url,
              let root = appState.currentProjectRoot else { return }

        // 复制到 imported
        let fm = FileManager.default
        let dest = root.appendingPathComponent("media/imported/cover_source_\(candidates.count + 1).\(url.pathExtension)")
        try? fm.copyItem(at: url, to: dest)

        let relativePath = "media/imported/\(dest.lastPathComponent)"
        coverService.updateBackground(sourcePath: relativePath, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func importLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .svg]
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url,
              let root = appState.currentProjectRoot else { return }

        let fm = FileManager.default
        let count = appState.currentProject?.mediaItems.filter { $0.type == .logo }.count ?? 0
        let ext = url.pathExtension
        let dest = root.appendingPathComponent("media/imported/logo_\(String(format: "%03d", count + 1)).\(ext)")
        try? fm.copyItem(at: url, to: dest)

        let relativePath = "media/imported/\(dest.lastPathComponent)"
        coverService.setLogo(path: relativePath, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func exportCover() {
        guard let project = appState.currentProject,
              let root = appState.currentProjectRoot else { return }
        try? coverService.exportCover(project: project, projectRoot: root)
    }
}

// MARK: - 候选帧

struct CandidateFrame: View {
    let path: String
    let projectRoot: URL
    let isSelected: Bool

    var body: some View {
        let url = projectRoot.appendingPathComponent(path)
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        } placeholder: {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 107, height: 60)
        }
    }
}
