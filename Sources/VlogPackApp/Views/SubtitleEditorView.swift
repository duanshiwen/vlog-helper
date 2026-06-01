import SwiftUI
import AppKit
import VlogPackCore

/// 字幕编辑器视图
struct SubtitleEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var subtitleService = SubtitleService()
    @State private var transcriptionService = TranscriptionService()
    @State private var searchText = ""
    @State private var isTranscribing = false
    @State private var transcriptionError: String?
    @State private var exportMessage: String?
    @State private var showBatchEditor = false
    @State private var batchFind = ""
    @State private var batchReplace = ""
    @State private var batchPrefix = ""
    @State private var batchSuffix = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Button {
                    transcribe()
                } label: {
                    HStack(spacing: 4) {
                        if isTranscribing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "waveform.badge.magnifyingglass")
                        }
                        Text(isTranscribing ? "转写中…" : "生成字幕")
                    }
                }
                .disabled(isTranscribing || !hasClips)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if !segments.isEmpty {
                    Text("\(segments.count) 条字幕")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showBatchEditor.toggle()
                } label: {
                    Label("批量修改", systemImage: showBatchEditor ? "chevron.up" : "text.badge.checkmark")
                }
                .controlSize(.small)
                .disabled(segments.isEmpty)

                Menu {
                    Button("导出 SRT") { exportSRT() }
                    Button("导出 ASS") { exportASS() }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
                .disabled(segments.isEmpty)
            }
            .padding(8)

            if let error = transcriptionError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
            }
            if let msg = exportMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            if showBatchEditor {
                batchEditor
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }

            // 搜索
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索字幕…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // 字幕列表
            if segments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text(hasClips ? "点击「生成字幕」开始转写" : "请先完成粗剪")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredSegments) { segment in
                        SubtitleSegmentRow(
                            segment: segment,
                            onUpdateText: { newText in
                                guard var p = appState.currentProject else { return }
                                subtitleService.updateText(
                                    segmentId: segment.id,
                                    text: newText,
                                    project: &p
                                )
                                appState.currentProject = p
                                try? appState.saveCurrentProject()
                            },
                            onMerge: {
                                guard var p = appState.currentProject else { return }
                                subtitleService.mergeWithNext(
                                    segmentId: segment.id,
                                    project: &p
                                )
                                appState.currentProject = p
                                try? appState.saveCurrentProject()
                            },
                            onDelete: {
                                guard var p = appState.currentProject else { return }
                                subtitleService.deleteSegment(
                                    segmentId: segment.id,
                                    project: &p
                                )
                                appState.currentProject = p
                                try? appState.saveCurrentProject()
                            }
                        )
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            }

            // 样式编辑器
            Divider()
            SubtitleStyleEditor()
        }
    }

    // MARK: - 批量修改

    private var batchEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("查找", text: $batchFind)
                    .textFieldStyle(.roundedBorder)
                TextField("替换为", text: $batchReplace)
                    .textFieldStyle(.roundedBorder)
                Button("全部替换") { applyBatchReplace() }
                    .disabled(batchFind.isEmpty)
            }
            HStack {
                TextField("统一前缀", text: $batchPrefix)
                    .textFieldStyle(.roundedBorder)
                TextField("统一后缀", text: $batchSuffix)
                    .textFieldStyle(.roundedBorder)
                Button("添加前后缀") { applyBatchWrap() }
                    .disabled(batchPrefix.isEmpty && batchSuffix.isEmpty)
            }
        }
        .font(.caption)
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func applyBatchReplace() {
        guard var p = appState.currentProject else { return }
        subtitleService.replaceText(find: batchFind, replaceWith: batchReplace, project: &p)
        appState.currentProject = p
        try? appState.saveCurrentProject()
        exportMessage = "已完成批量替换"
    }

    private func applyBatchWrap() {
        guard var p = appState.currentProject else { return }
        subtitleService.wrapText(prefix: batchPrefix, suffix: batchSuffix, project: &p)
        appState.currentProject = p
        try? appState.saveCurrentProject()
        exportMessage = "已完成批量添加前后缀"
    }

    // MARK: - Helpers

    private var segments: [SubtitleSegment] {
        appState.currentProject?.subtitles?.segments ?? []
    }

    private var filteredSegments: [SubtitleSegment] {
        guard !searchText.isEmpty else { return segments }
        guard let project = appState.currentProject else { return [] }
        return subtitleService.searchSegments(
            query: searchText,
            project: project
        )
    }

    private var hasClips: Bool {
        !(appState.currentProject?.timeline.videoTrack?.clips.isEmpty ?? true)
    }

    private func transcribe() {
        guard let root = appState.currentProjectRoot,
              let project = appState.currentProject else { return }

        isTranscribing = true
        transcriptionError = nil

        let svc = transcriptionService
        let projectCopy = project
        let projectRoot = root

        Task.detached {
            do {
                let doc = try svc.transcribeFromTimeline(
                    project: projectCopy,
                    projectRoot: projectRoot,
                    language: "zh"
                )
                await MainActor.run {
                    guard var p = self.appState.currentProject else { return }
                    p.subtitles = doc
                    self.applySubtitlesToTrack(doc: doc, project: &p)
                    self.appState.currentProject = p
                    try? self.appState.saveCurrentProject()
                }
            } catch {
                await MainActor.run {
                    self.transcriptionError = "转写失败：\(error.localizedDescription)"
                }
            }
            await MainActor.run {
                self.isTranscribing = false
            }
        }
    }

    /// 将字幕段应用到字幕轨道（纯函数，不持有 appState）
    private func applySubtitlesToTrack(doc: SubtitleDocument, project: inout VlogProject) {
        let timelineService = TimelineService()
        // 确保有字幕轨道
        let subtitleTrack: Track
        if let existing = project.timeline.subtitleTrack {
            subtitleTrack = existing
        } else {
            subtitleTrack = timelineService.addTrack(type: .subtitle, name: "字幕", project: &project)
        }
        // 清空旧字幕 clips
        if let idx = project.timeline.tracks.firstIndex(where: { $0.id == subtitleTrack.id }) {
            project.timeline.tracks[idx].clips = []
        }
        // 为每个字幕段创建 clip
        for segment in doc.segments {
            let clip = TimelineClip(
                mediaItemId: "subtitle", // 占位
                trackId: subtitleTrack.id,
                inPoint: segment.start,
                outPoint: segment.end,
                startTime: segment.start,
                order: project.timeline.tracks[project.timeline.tracks.firstIndex(where: { $0.id == subtitleTrack.id })!].clips.count,
                subtitleText: segment.text
            )
            if let idx = project.timeline.tracks.firstIndex(where: { $0.id == subtitleTrack.id }) {
                project.timeline.tracks[idx].clips.append(clip)
            }
        }
    }

    private func exportSRT() {
        guard let project = appState.currentProject else { return }
        let srt = subtitleService.exportSRT(project: project)
        saveToPanel(content: srt, defaultName: "subtitles.srt", typeName: "srt")
    }

    private func exportASS() {
        guard let project = appState.currentProject else { return }
        let ass = subtitleService.exportASS(project: project)
        saveToPanel(content: ass, defaultName: "subtitles.ass", typeName: "ass")
    }

    private func saveToPanel(content: String, defaultName: String, typeName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.init(filenameExtension: typeName) ?? .plainText]
        panel.canCreateDirectories = true
        panel.title = "导出 \(typeName.uppercased())"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "已导出到 \(url.lastPathComponent)"
                // 3 秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { exportMessage = nil }
                }
            } catch {
                transcriptionError = "导出失败：\(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 字幕行

struct SubtitleSegmentRow: View {
    let segment: SubtitleSegment
    let onUpdateText: (String) -> Void
    let onMerge: () -> Void
    let onDelete: () -> Void

    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatTime(segment.start))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("→")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(formatTime(segment.end))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onMerge()
                } label: {
                    Image(systemName: "arrow.merge")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("合并到下一条")
                .controlSize(.mini)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
            }

            TextField("字幕文本", text: $editedText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(1...4)
                .focused($isFocused)
                .onSubmit {
                    saveIfNeeded()
                }
        }
        .padding(.vertical, 4)
        .onAppear {
            editedText = segment.text
        }
        .onChange(of: segment.text) { _, newText in
            // 只在未编辑时同步外部变化
            if !isFocused && newText != editedText {
                editedText = newText
            }
        }
        .onChange(of: isFocused) { _, focused in
            // 失去焦点时保存
            if !focused {
                saveIfNeeded()
            }
        }
    }

    private func saveIfNeeded() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != segment.text {
            onUpdateText(trimmed)
        }
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 100)
        return String(format: "%d:%02d.%02d", m, s, ms)
    }
}
