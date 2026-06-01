import SwiftUI
import UniformTypeIdentifiers
import VlogPackCore

/// 多轨时间线视图
struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var timelineService = TimelineService()
    @State private var trimDialogClip: TimelineClip?
    @State private var trimDialogType: TrimType = .inPoint
    @State private var trimValue: String = ""
    @State private var zoom: Double = 1.0
    @State private var activeTool: TimelineTool = .select
    @State private var magneticSnap: Bool = true

    enum TimelineTool {
        case select
        case shuttle
        case blade
    }

    enum TrimType {
        case inPoint, outPoint
    }

    var body: some View {
        VStack(spacing: 0) {
            // 时间线标题栏
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "timeline.selection")
                        .foregroundStyle(.secondary)
                    Text("时间线")
                        .font(.headline)
                    Text(activeToolLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 12)

                Text("\(formatDuration(appState.timelinePlayheadTime)) / \(formatDuration(totalDuration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 112, alignment: .trailing)

                Toggle(isOn: $magneticSnap) {
                    Image(systemName: "magnet")
                }
                .toggleStyle(.button)
                .controlSize(.mini)
                .help("时间线磁性吸附")

                HStack(spacing: 6) {
                    Button { zoom = max(0.5, zoom - 0.25) } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("缩小时间线")

                    Slider(value: $zoom, in: 0.5...4.0)
                        .frame(width: 120)

                    Button { zoom = min(4.0, zoom + 0.25) } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help("放大时间线")

                    Text("\(Int(zoom * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Menu {
                    Button("添加音频轨道") { addTrack(.audio) }
                    Button("添加字幕轨道") { addTrack(.subtitle) }
                } label: {
                    Label("添加轨道", systemImage: "plus.rectangle.on.rectangle")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help("添加轨道")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            Divider()

            // 轨道列表
            if tracks.isEmpty {
                emptyTimelineView
            } else {
                HStack(spacing: 0) {
                    timelineToolRail
                    Divider()
                    ScrollView(.horizontal) {
                        ScrollView(.vertical) {
                            VStack(spacing: 1) {
                                TimelineRulerView(
                                    duration: max(totalDuration, 1),
                                    pixelsPerSecond: pixelsPerSecond,
                                    width: timelineCanvasWidth,
                                    playheadTime: appState.timelinePlayheadTime,
                                    onSetPlayhead: { appState.timelinePlayheadTime = snappedTime($0) }
                                )
                                .padding(.leading, 116)

                                ForEach(sortedTracks) { track in
                                TrackRowView(
                                track: track,
                                selectedClipId: appState.selectedClipId,
                                onSelectClip: { clipId in
                                    appState.selectedClipId = clipId
                                    if let clip = appState.currentProject?.timeline.clip(byId: clipId) {
                                        appState.timelinePlayheadTime = clip.startTime
                                    }
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
                                },
                                    onMoveClip: { clipId, targetTrackId, targetIndex in
                                        moveClip(clipId: clipId, toTrack: targetTrackId, index: targetIndex)
                                    },
                                    timelineDuration: max(totalDuration, 1),
                                    pixelsPerSecond: pixelsPerSecond,
                                    onSetStartTime: { clipId, startTime in
                                        setClipStartTime(clipId: clipId, startTime: startTime)
                                    },
                                    onSetVolume: { clipId, volume in
                                        setClipVolume(clipId: clipId, volume: volume)
                                    },
                                            onSplitClip: { clipId, relativeTime in
                                            splitClip(clipId: clipId, at: relativeTime)
                                        },
                                        activeTool: activeTool,
                                        magneticSnap: magneticSnap,
                                        playheadTime: appState.timelinePlayheadTime,
                                        onSetPlayhead: { appState.timelinePlayheadTime = snappedTime($0) }
                                    )
                                }
                            }
                            .padding(8)
                        }
                        .frame(minWidth: timelineCanvasWidth + 128)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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

    // MARK: - 工具栏

    private var timelineToolRail: some View {
        VStack(spacing: 6) {
            toolButton(.select, icon: "cursorarrow", help: "选择/移动工具")
            toolButton(.shuttle, icon: "timeline.selection", help: "飞梭/播放头工具：点击或拖动设置时间位置")
            toolButton(.blade, icon: "scissors", help: "自由切分工具：点击片段上的位置进行切分")
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
    }

    private func toolButton(_ tool: TimelineTool, icon: String, help: String) -> some View {
        Button { activeTool = tool } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: activeTool == tool ? .semibold : .regular))
                .foregroundStyle(activeTool == tool ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .background(activeTool == tool ? Color.accentColor.opacity(0.16) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(activeTool == tool ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(help)
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

    private var pixelsPerSecond: CGFloat { CGFloat(12 * zoom) }

    private var selectedClip: TimelineClip? {
        guard let id = appState.selectedClipId else { return nil }
        return appState.currentProject?.timeline.clip(byId: id)
    }

    private var activeToolLabel: String {
        switch activeTool {
        case .select: return "选择"
        case .shuttle: return "飞梭"
        case .blade: return "剪刀"
        }
    }

    private var timelineCanvasWidth: CGFloat {
        max(520, CGFloat(max(totalDuration, 1)) * pixelsPerSecond)
    }

    private func mediaItem(for clip: TimelineClip) -> MediaItem? {
        appState.currentProject?.mediaItems.first { $0.id == clip.mediaItemId }
    }

    private func snappedTime(_ rawTime: Double, excludingClipId: String? = nil) -> Double {
        let clamped = max(0, rawTime)
        guard magneticSnap, let project = appState.currentProject else { return clamped }
        var candidates: [Double] = [0, clamped.rounded()]
        for track in project.timeline.tracks {
            for clip in track.clips where clip.id != excludingClipId {
                candidates.append(clip.startTime)
                candidates.append(clip.endTime)
            }
        }
        let threshold = max(0.08, Double(8 / pixelsPerSecond))
        return candidates.min(by: { abs($0 - clamped) < abs($1 - clamped) }).flatMap {
            abs($0 - clamped) <= threshold ? max(0, $0) : clamped
        } ?? clamped
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
        guard var project = appState.currentProject else { return }
        if appState.selectedClipId == clip.id {
            appState.selectedClipId = nil
        }
        timelineService.removeClip(clipId: clip.id, project: &project)
        appState.currentProject = project
        try? appState.saveCurrentProject()
    }

    private func setClipVolume(clipId: String, volume: Double) {
        guard var project = appState.currentProject else { return }
        do {
            try timelineService.setVolume(clipId: clipId, volume: volume, project: &project)
            appState.currentProject = project
            appState.selectedClipId = clipId
            try? appState.saveCurrentProject()
        } catch {
            // 非法音量直接忽略
        }
    }

    private func setClipStartTime(clipId: String, startTime: Double) {
        guard var project = appState.currentProject else { return }
        do {
            try timelineService.setStartTime(clipId: clipId, startTime: snappedTime(startTime, excludingClipId: clipId), project: &project)
            appState.currentProject = project
            appState.selectedClipId = clipId
            try? appState.saveCurrentProject()
        } catch {
            // 非法定位直接忽略
        }
    }

    private func splitSelectedClip() {
        guard let clip = selectedClip else { return }
        splitClip(clipId: clip.id, at: clip.duration / 2)
    }

    private func splitClip(clipId: String, at relativeTime: Double) {
        guard var project = appState.currentProject else { return }
        do {
            _ = try timelineService.splitClip(clipId: clipId, atRelativeTime: relativeTime, project: &project)
            appState.currentProject = project
            try? appState.saveCurrentProject()
        } catch {
            // 非法切分直接忽略
        }
    }

    private func moveClip(clipId: String, toTrack targetTrackId: String, index targetIndex: Int) {
        guard var project = appState.currentProject else { return }
        do {
            if project.timeline.track(containingClipId: clipId)?.id != targetTrackId {
                try timelineService.moveClip(clipId: clipId, toTrack: targetTrackId, project: &project)
            }
            try timelineService.moveClip(clipId: clipId, to: targetIndex, project: &project)
            appState.currentProject = project
            appState.selectedClipId = clipId
            try? appState.saveCurrentProject()
        } catch {
            // 暂不打断编辑流程；非法拖放直接忽略
        }
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

// MARK: - 时间码标尺

struct TimelineRulerView: View {
    let duration: Double
    let pixelsPerSecond: CGFloat
    let width: CGFloat
    let playheadTime: Double
    let onSetPlayhead: (Double) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
            ForEach(0...Int(ceil(duration)), id: \.self) { second in
                VStack(alignment: .leading, spacing: 2) {
                    Rectangle()
                        .fill(second % majorStep == 0 ? Color.secondary.opacity(0.55) : Color.secondary.opacity(0.22))
                        .frame(width: 1, height: second % majorStep == 0 ? 12 : 6)
                    if second % majorStep == 0 {
                        Text(formatTime(Double(second)))
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .offset(x: CGFloat(second) * pixelsPerSecond)
            }
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 1.5)
                .offset(x: CGFloat(playheadTime) * pixelsPerSecond)
        }
        .frame(width: width, height: 28)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onSetPlayhead(Double(max(0, value.location.x) / pixelsPerSecond))
                }
        )
    }

    private var majorStep: Int {
        if pixelsPerSecond >= 36 { return 1 }
        if pixelsPerSecond >= 18 { return 5 }
        return 10
    }

    private func formatTime(_ t: Double) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
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
    let onMoveClip: (String, String, Int) -> Void
    let timelineDuration: Double
    let pixelsPerSecond: CGFloat
    let onSetStartTime: (String, Double) -> Void
    let onSetVolume: (String, Double) -> Void
    let onSplitClip: (String, Double) -> Void
    let activeTool: TimelineView.TimelineTool
    let magneticSnap: Bool
    let playheadTime: Double
    let onSetPlayhead: (Double) -> Void
    @State private var dragStartTimes: [String: Double] = [:]
    @State private var hoverXByClipId: [String: CGFloat] = [:]

    private let headerWidth: CGFloat = 108
    private let menuWidth: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                trackHeader

                ZStack(alignment: .leading) {
                    timelineGrid

                    Rectangle()
                        .fill(Color.red.opacity(0.75))
                        .frame(width: 1.5, height: rowHeight)
                        .offset(x: CGFloat(playheadTime) * pixelsPerSecond)
                        .allowsHitTesting(false)

                    if track.clips.isEmpty {
                        Text(emptyText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 8)
                    } else {
                        ForEach(Array(track.sortedClips.enumerated()), id: \.element.id) { index, clip in
                            ClipView(
                                clip: clip,
                                trackType: track.type,
                                isSelected: clip.id == selectedClipId,
                                displayWidth: clipWidth(clip),
                                onSetVolume: { volume in onSetVolume(clip.id, volume) }
                            )
                            .position(
                                x: clipX(clip) + clipWidth(clip) / 2,
                                y: rowHeight / 2
                            )
                            .onTapGesture {
                                if activeTool == .blade {
                                    let x = min(max(hoverXByClipId[clip.id] ?? clipWidth(clip) / 2, 0), clipWidth(clip))
                                    let relativeTime = Double(x / pixelsPerSecond)
                                    onSplitClip(clip.id, relativeTime)
                                } else {
                                    onSelectClip(clip.id)
                                }
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoverXByClipId[clip.id] = location.x
                                case .ended:
                                    hoverXByClipId[clip.id] = nil
                                }
                            }
                            .onDrag {
                                onSelectClip(clip.id)
                                return NSItemProvider(object: clip.id as NSString)
                            }
                            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                                handleDrop(providers: providers, targetIndex: index)
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { value in
                                        guard activeTool == .select else { return }
                                        if dragStartTimes[clip.id] == nil {
                                            dragStartTimes[clip.id] = clip.startTime
                                        }
                                        let base = dragStartTimes[clip.id] ?? clip.startTime
                                        let newStart = max(0, base + Double(value.translation.width / pixelsPerSecond))
                                        onSetStartTime(clip.id, newStart)
                                    }
                                    .onEnded { _ in
                                        dragStartTimes[clip.id] = nil
                                    }
                            )
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
                .frame(width: canvasWidth, height: rowHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: activeTool == .shuttle ? 0 : 999_999)
                        .onChanged { value in
                            guard activeTool == .shuttle else { return }
                            onSetPlayhead(Double(max(0, value.location.x) / pixelsPerSecond))
                        }
                )
                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                    handleDrop(providers: providers, targetIndex: track.sortedClips.count)
                }

                trackMenu
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trackBg)

            Divider()
        }
    }

    private var trackHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: track.type.iconName)
                    .font(.caption2)
                    .foregroundStyle(trackColor)
                Text(track.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(width: 72, alignment: .leading)

            Button {
                onToggleMute()
            } label: {
                Image(systemName: track.isMuted ? "speaker.slash" : "speaker.wave.2")
                    .font(.caption2)
                    .foregroundStyle(track.isMuted ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 20)
        }
        .frame(width: headerWidth, alignment: .leading)
    }

    private var trackMenu: some View {
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
        .frame(width: menuWidth)
    }

    private var timelineGrid: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color(nsColor: .textBackgroundColor).opacity(0.45))
            ForEach(0...Int(ceil(timelineDuration)), id: \.self) { second in
                Rectangle()
                    .fill(second % 5 == 0 ? Color.secondary.opacity(0.22) : Color.secondary.opacity(0.08))
                    .frame(width: second % 5 == 0 ? 1 : 0.5)
                    .offset(x: CGFloat(second) * pixelsPerSecond)
            }
        }
    }

    private var canvasWidth: CGFloat {
        max(520, CGFloat(max(timelineDuration, 1)) * pixelsPerSecond)
    }

    private var rowHeight: CGFloat {
        switch track.type {
        case .video:    return 72
        case .audio:    return 58
        case .subtitle: return 48
        }
    }

    private func clipStartOnTimeline(_ clip: TimelineClip) -> Double {
        clip.startTime
    }

    private func clipX(_ clip: TimelineClip) -> CGFloat {
        CGFloat(clipStartOnTimeline(clip)) * pixelsPerSecond
    }

    private func clipWidth(_ clip: TimelineClip) -> CGFloat {
        max(28, CGFloat(clip.duration) * pixelsPerSecond)
    }

    private func handleDrop(providers: [NSItemProvider], targetIndex: Int) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let clipId = object as? String else { return }
            DispatchQueue.main.async {
                onMoveClip(clipId, track.id, targetIndex)
            }
        }
        return true
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
    var displayWidth: CGFloat? = nil
    var onSetVolume: ((Double) -> Void)? = nil

    var body: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : clipColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .frame(width: displayWidth ?? clipWidth, height: trackHeight)
                .overlay(alignment: .leading) {
                    clipContent
                        .padding(.horizontal, 4)
                }

            HStack(spacing: 4) {
                Text("\(formatTime(clip.inPoint)) — \(formatTime(clip.outPoint))")
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.secondary)
                if isSelected, trackType != .subtitle, let onSetVolume {
                    Slider(
                        value: Binding(
                            get: { clip.volume },
                            set: { onSetVolume($0) }
                        ),
                        in: 0...2
                    )
                    .frame(width: min(max((displayWidth ?? clipWidth) - 82, 34), 90))
                    Text("\(Int(clip.volume * 100))%")
                        .font(.system(size: 8).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
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
