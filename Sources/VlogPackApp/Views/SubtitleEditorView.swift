import SwiftUI
import VlogPackCore

/// 字幕编辑器视图
struct SubtitleEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var subtitleService = SubtitleService()
    @State private var transcriptionService = TranscriptionService()
    @State private var searchText = ""
    @State private var isTranscribing = false
    @State private var transcriptionError: String?

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

                Spacer()

                Button("导出 SRT") { exportSRT() }
                    .controlSize(.small)
                    .disabled(segments.isEmpty)

                Button("导出 ASS") { exportASS() }
                    .controlSize(.small)
                    .disabled(segments.isEmpty)
            }
            .padding(8)

            if let error = transcriptionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
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
                                subtitleService.updateText(
                                    segmentId: segment.id,
                                    text: newText,
                                    project: &appState.currentProject!
                                )
                                try? appState.saveCurrentProject()
                            },
                            onMerge: {
                                subtitleService.mergeWithNext(
                                    segmentId: segment.id,
                                    project: &appState.currentProject!
                                )
                                try? appState.saveCurrentProject()
                            },
                            onDelete: {
                                subtitleService.deleteSegment(
                                    segmentId: segment.id,
                                    project: &appState.currentProject!
                                )
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

    // MARK: - Helpers

    private var segments: [SubtitleSegment] {
        appState.currentProject?.subtitles?.segments ?? []
    }

    private var filteredSegments: [SubtitleSegment] {
        guard !searchText.isEmpty else { return segments }
        return subtitleService.searchSegments(
            query: searchText,
            project: appState.currentProject!
        )
    }

    private var hasClips: Bool {
        !(appState.currentProject?.timeline.clips.isEmpty ?? true)
    }

    private func transcribe() {
        guard let root = appState.currentProjectRoot,
              appState.currentProject != nil else { return }

        isTranscribing = true
        transcriptionError = nil

        let svc = transcriptionService

        Task {
            do {
                try svc.transcribeFromTimeline(
                    project: &appState.currentProject!,
                    projectRoot: root,
                    language: "zh"
                )
                try? appState.saveCurrentProject()
            } catch {
                transcriptionError = "转写失败：\(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }

    private func exportSRT() {
        guard let project = appState.currentProject,
              let root = appState.currentProjectRoot else { return }

        let srt = subtitleService.exportSRT(project: project)
        let url = root.appendingPathComponent("exports/subtitles.srt")
        try? srt.write(to: url, atomically: true, encoding: .utf8)
    }

    private func exportASS() {
        guard let project = appState.currentProject,
              let root = appState.currentProjectRoot else { return }

        let ass = subtitleService.exportASS(project: project)
        let url = root.appendingPathComponent("exports/subtitles.ass")
        try? ass.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - 字幕行

struct SubtitleSegmentRow: View {
    let segment: SubtitleSegment
    let onUpdateText: (String) -> Void
    let onMerge: () -> Void
    let onDelete: () -> Void

    @State private var editedText: String = ""

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
                .onSubmit {
                    onUpdateText(editedText)
                }
                .onChange(of: editedText) { _, newValue in
                    // 实时保存（debounce 可以在后续优化）
                }
        }
        .padding(.vertical, 4)
        .onAppear {
            editedText = segment.text
        }
        .onChange(of: segment.text) { _, newText in
            if newText != editedText {
                editedText = newText
            }
        }
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 100)
        return String(format: "%d:%02d.%02d", m, s, ms)
    }
}
