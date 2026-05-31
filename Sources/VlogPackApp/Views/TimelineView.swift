import SwiftUI
import VlogPackCore

/// 时间线视图
struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var timelineService = TimelineService()
    @State private var trimDialogClip: TimelineClip?
    @State private var trimDialogType: TrimType = .inPoint
    @State private var trimValue: String = ""

    enum TrimType {
        case inPoint, outPoint
    }

    var body: some View {
        VStack(spacing: 0) {
            // 时间线标题栏
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundStyle(.secondary)
                Text("时间线")
                    .font(.headline)
                Spacer()
                Text(formatDuration(totalDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !clips.isEmpty {
                    Text("\(clips.count) 个片段")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // 时间线内容
            if clips.isEmpty {
                emptyTimelineView
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(clips) { clip in
                            TimelineClipView(
                                clip: clip,
                                mediaItem: mediaItem(for: clip),
                                isSelected: clip.id == appState.selectedClipId
                            )
                            .onTapGesture {
                                appState.selectedClipId = clip.id
                            }
                            .contextMenu {
                                Button("裁剪开头…") {
                                    trimDialogType = .inPoint
                                    trimValue = formatTime(clip.inPoint)
                                    trimDialogClip = clip
                                }
                                Button("裁剪结尾…") {
                                    trimDialogType = .outPoint
                                    trimValue = formatTime(clip.outPoint)
                                    trimDialogClip = clip
                                }
                                Divider()
                                Button("裁掉前 5 秒") {
                                    trimFromStart(clip: clip, seconds: 5)
                                }
                                Button("裁掉后 5 秒") {
                                    trimFromEnd(clip: clip, seconds: 5)
                                }
                                Divider()
                                Button("重置裁剪") {
                                    resetTrim(clip: clip)
                                }
                                Divider()
                                Button("移除", role: .destructive) {
                                    removeClip(clip)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(item: $trimDialogClip) { clip in
            TrimDialog(
                clip: clip,
                mediaItem: mediaItem(for: clip),
                type: trimDialogType,
                value: $trimValue,
                onConfirm: { newValue in
                    applyTrim(clip: clip, type: trimDialogType, value: newValue)
                    trimDialogClip = nil
                },
                onCancel: {
                    trimDialogClip = nil
                }
            )
        }
    }

    private var emptyTimelineView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("从素材库拖入或右键添加素材")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var clips: [TimelineClip] {
        appState.currentProject?.timeline.sortedClips ?? []
    }

    private var totalDuration: Double {
        appState.currentProject?.timeline.totalDuration ?? 0
    }

    private func mediaItem(for clip: TimelineClip) -> MediaItem? {
        appState.currentProject?.mediaItems.first { $0.id == clip.mediaItemId }
    }

    private func removeClip(_ clip: TimelineClip) {
        guard appState.currentProject != nil else { return }
        if appState.selectedClipId == clip.id {
            appState.selectedClipId = nil
        }
        timelineService.removeClip(clipId: clip.id, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    // MARK: - Trim Actions

    private func trimFromStart(clip: TimelineClip, seconds: Double) {
        guard appState.currentProject != nil else { return }
        let newIn = min(clip.inPoint + seconds, clip.outPoint - 0.1)
        try? timelineService.setInPoint(clipId: clip.id, inPoint: newIn, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func trimFromEnd(clip: TimelineClip, seconds: Double) {
        guard appState.currentProject != nil else { return }
        let newOut = max(clip.outPoint - seconds, clip.inPoint + 0.1)
        try? timelineService.setOutPoint(clipId: clip.id, outPoint: newOut, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func resetTrim(clip: TimelineClip) {
        guard appState.currentProject != nil, let media = mediaItem(for: clip) else { return }
        try? timelineService.setInPoint(clipId: clip.id, inPoint: 0, project: &appState.currentProject!)
        try? timelineService.setOutPoint(clipId: clip.id, outPoint: media.duration, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func applyTrim(clip: TimelineClip, type: TrimType, value: String) {
        guard appState.currentProject != nil else { return }
        guard let seconds = parseTime(value) else { return }
        switch type {
        case .inPoint:
            try? timelineService.setInPoint(clipId: clip.id, inPoint: seconds, project: &appState.currentProject!)
        case .outPoint:
            try? timelineService.setOutPoint(clipId: clip.id, outPoint: seconds, project: &appState.currentProject!)
        }
        try? appState.saveCurrentProject()
    }

    private func formatDuration(_ d: Double) -> String {
        let h = Int(d) / 3600
        let m = (Int(d) % 3600) / 60
        let s = Int(d) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }

    private func parseTime(_ str: String) -> Double? {
        let parts = str.split(separator: ":")
        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
            return m * 60 + s
        }
        return Double(str)
    }
}

// MARK: - 裁剪对话框

struct TrimDialog: View {
    let clip: TimelineClip
    let mediaItem: MediaItem?
    let type: TimelineView.TrimType
    @Binding var value: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(type == .inPoint ? "设置入点" : "设置出点")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("片段: \(mediaItem?.originalFileName ?? "未知")")
                    .font(.callout)
                if type == .inPoint {
                    Text("入点必须在 0 到 \(formatTime(clip.outPoint)) 之间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("出点必须在 \(formatTime(clip.inPoint)) 到 \(formatTime(mediaItem?.duration ?? 0)) 之间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("时间:")
                    TextField("m:ss.s", text: $value)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospacedDigit())
                        .frame(width: 100)
                }
            }

            HStack {
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("确定") { onConfirm(value) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}

// MARK: - 时间线片段视图

struct TimelineClipView: View {
    let clip: TimelineClip
    let mediaItem: MediaItem?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color(nsColor: .separatorColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .frame(width: clipWidth, height: 48)
                .overlay(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(mediaItem?.originalFileName ?? "Unknown")
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 6)
                }

            Text("\(formatTime(clip.inPoint)) — \(formatTime(clip.outPoint))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var clipWidth: CGFloat {
        let duration = clip.duration
        return max(80, min(300, CGFloat(duration) * 10))
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}
