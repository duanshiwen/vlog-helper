import SwiftUI
import VlogPackCore

/// 多轨时间线视图
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
                Menu {
                    Button("添加音频轨道") { addTrack(.audio) }
                    Button("添加字幕轨道") { addTrack(.subtitle) }
                } label: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // 轨道列表
            if tracks.isEmpty {
                emptyTimelineView
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 1) {
                        ForEach(sortedTracks) { track in
                            TrackRowView(
                                track: track,
                                selectedClipId: appState.selectedClipId,
                                onSelectClip: { clipId in
                                    appState.selectedClipId = clipId
                                },
                                onRemoveClip: { clip in
                                    removeClip(clip)
                                },
                                onTrimClip: { clip, type in
                                    trimDialogType = type
                                    trimValue = type == .inPoint
                                        ? formatTime(clip.inPoint)
                                        : formatTime(clip.outPoint)
                                    trimDialogClip = clip
                                },
                                onQuickTrim: { clip, seconds, fromEnd in
                                    if fromEnd {
                                        trimFromEnd(clip: clip, seconds: seconds)
                                    } else {
                                        trimFromStart(clip: clip, seconds: seconds)
                                    }
                                },
                                onResetTrim: { clip in
                                    resetTrim(clip: clip)
                                },
                                onToggleMute: {
                                    toggleMute(track: track)
                                },
                                onRemoveTrack: {
                                    removeTrack(track: track)
                                }
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - 空状态

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

    // MARK: - 数据源

    private var tracks: [Track] {
        appState.currentProject?.timeline.tracks ?? []
    }

    private var sortedTracks: [Track] {
        appState.currentProject?.timeline.sortedTracks ?? []
    }

    private var totalDuration: Double {
        appState.currentProject?.timeline.totalDuration ?? 0
    }

    private func mediaItem(for clip: TimelineClip) -> MediaItem? {
        appState.currentProject?.mediaItems.first { $0.id == clip.mediaItemId }
    }

    // MARK: - 轨道操作

    private func addTrack(_ type: TrackType) {
        guard appState.currentProject != nil else { return }
        timelineService.addTrack(type: type, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func removeTrack(track: Track) {
        guard appState.currentProject != nil else { return }
        timelineService.removeTrack(trackId: track.id, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func toggleMute(track: Track) {
        guard appState.currentProject != nil else { return }
        try? timelineService.toggleMute(trackId: track.id, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    // MARK: - 片段操作

    private func removeClip(_ clip: TimelineClip) {
        guard appState.currentProject != nil else { return }
        if appState.selectedClipId == clip.id {
            appState.selectedClipId = nil
        }
        timelineService.removeClip(clipId: clip.id, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    // MARK: - Trim

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

    // MARK: - 格式化

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

// MARK: - 轨道行视图

struct TrackRowView: View {
    let track: Track
    let selectedClipId: String?
    let onSelectClip: (String) -> Void
    let onRemoveClip: (TimelineClip) -> Void
    let onTrimClip: (TimelineClip, TimelineView.TrimType) -> Void
    let onQuickTrim: (TimelineClip, Double, Bool) -> Void
    let onResetTrim: (TimelineClip) -> Void
    let onToggleMute: () -> Void
    let onRemoveTrack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 轨道标签
                HStack(spacing: 4) {
                    Image(systemName: track.type.iconName)
                        .font(.caption2)
                        .foregroundStyle(trackColor)
                    Text(track.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .frame(width: 72, alignment: .leading)

                // 静音按钮
                Button {
                    onToggleMute()
                } label: {
                    Image(systemName: track.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .font(.caption2)
                        .foregroundStyle(track.isMuted ? .red : .secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 20)

                // 片段列表
                if track.clips.isEmpty {
                    Text(emptyText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 4) {
                            ForEach(track.sortedClips) { clip in
                                ClipView(
                                    clip: clip,
                                    trackType: track.type,
                                    isSelected: clip.id == selectedClipId
                                )
                                .onTapGesture { onSelectClip(clip.id) }
                                .contextMenu {
                                    if track.type == .video {
                                        Button("裁剪开头…") { onTrimClip(clip, .inPoint) }
                                        Button("裁剪结尾…") { onTrimClip(clip, .outPoint) }
                                        Divider()
                                        Button("裁掉前 5 秒") { onQuickTrim(clip, 5, false) }
                                        Button("裁掉后 5 秒") { onQuickTrim(clip, 5, true) }
                                        Divider()
                                        Button("重置裁剪") { onResetTrim(clip) }
                                        Divider()
                                    }
                                    Button("移除", role: .destructive) { onRemoveClip(clip) }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // 轨道菜单
                Menu {
                    if track.type != .video {
                        Button("删除轨道", role: .destructive) { onRemoveTrack() }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trackBg)

            Divider()
        }
    }

    private var trackColor: Color {
        switch track.type {
        case .video:    return .blue
        case .audio:    return .green
        case .subtitle: return .orange
        }
    }

    private var trackBg: Color {
        track.type == .video
            ? Color.blue.opacity(0.05)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var emptyText: String {
        switch track.type {
        case .video:    return "拖入视频素材"
        case .audio:    return "拖入音频素材"
        case .subtitle: return "生成或手动添加字幕"
        }
    }
}

// MARK: - 片段视图

struct ClipView: View {
    let clip: TimelineClip
    let trackType: TrackType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : clipColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .frame(width: clipWidth, height: trackHeight)
                .overlay(alignment: .leading) {
                    clipContent
                        .padding(.horizontal, 4)
                }

            Text("\(formatTime(clip.inPoint)) — \(formatTime(clip.outPoint))")
                .font(.system(size: 8).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var clipContent: some View {
        switch trackType {
        case .video:
            HStack(spacing: 2) {
                Image(systemName: "film")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(clip.mediaItemId.prefix(6))
                    .font(.system(size: 8))
                    .lineLimit(1)
            }
        case .audio:
            HStack(spacing: 2) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(clip.mediaItemId.prefix(6))
                    .font(.system(size: 8))
                    .lineLimit(1)
            }
        case .subtitle:
            Text(clip.subtitleText ?? "...")
                .font(.system(size: 9))
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    private var clipColor: Color {
        switch trackType {
        case .video:    return Color.blue.opacity(0.15)
        case .audio:    return Color.green.opacity(0.15)
        case .subtitle: return Color.orange.opacity(0.15)
        }
    }

    private var trackHeight: CGFloat {
        switch trackType {
        case .video:    return 40
        case .audio:    return 28
        case .subtitle: return 28
        }
    }

    private var clipWidth: CGFloat {
        let duration = clip.duration
        return max(60, min(250, CGFloat(duration) * 8))
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
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
