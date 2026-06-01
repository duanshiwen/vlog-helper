import Foundation

/// 时间线服务错误
public enum TimelineServiceError: Error, Sendable {
    case mediaItemNotFound(id: String)
    case invalidInPoint
    case invalidOutPoint
    case clipNotFound(id: String)
    case trackNotFound(id: String)
    case trackTypeMismatch(expected: TrackType, got: TrackType)
    case videoTrackRequired
}

/// 时间线服务
public final class TimelineService: @unchecked Sendable {
    public init() {}

    // MARK: - 轨道管理

    /// 添加新轨道
    @discardableResult
    public func addTrack(
        type: TrackType,
        name: String? = nil,
        project: inout VlogProject
    ) -> Track {
        let trackName = name ?? defaultTrackName(type: type, project: project)
        let track = Track(
            name: trackName,
            type: type,
            order: project.timeline.tracks.count
        )
        project.timeline.tracks.append(track)
        return track
    }

    /// 删除轨道
    public func removeTrack(
        trackId: String,
        project: inout VlogProject
    ) {
        project.timeline.tracks.removeAll { $0.id == trackId }
        reindexTracks(project: &project)
    }

    /// 切换轨道静音
    public func toggleMute(
        trackId: String,
        project: inout VlogProject
    ) throws {
        guard let idx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            throw TimelineServiceError.trackNotFound(id: trackId)
        }
        project.timeline.tracks[idx].isMuted.toggle()
    }

    /// 获取或创建默认视频轨道
    public func ensureVideoTrack(project: inout VlogProject) -> Track {
        if let existing = project.timeline.videoTrack {
            return existing
        }
        return addTrack(type: .video, name: "主视频", project: &project)
    }

    // MARK: - 添加片段

    /// 将素材添加到指定轨道末尾
    @discardableResult
    public func addClip(
        mediaItemId: String,
        toTrack trackId: String,
        project: inout VlogProject
    ) throws -> TimelineClip {
        guard let mediaItem = project.mediaItems.first(where: { $0.id == mediaItemId }) else {
            throw TimelineServiceError.mediaItemNotFound(id: mediaItemId)
        }
        guard let trackIndex = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            throw TimelineServiceError.trackNotFound(id: trackId)
        }

        let clip = TimelineClip(
            mediaItemId: mediaItemId,
            trackId: trackId,
            inPoint: 0,
            outPoint: mediaItem.duration > 0 ? mediaItem.duration : 0,
            startTime: nextStartTime(forTrackIndex: trackIndex, project: project),
            order: project.timeline.tracks[trackIndex].clips.count
        )
        project.timeline.tracks[trackIndex].clips.append(clip)
        return clip
    }

    /// 将素材添加到默认视频轨道
    @discardableResult
    public func addClip(
        mediaItemId: String,
        project: inout VlogProject
    ) throws -> TimelineClip {
        let track = ensureVideoTrack(project: &project)
        return try addClip(mediaItemId: mediaItemId, toTrack: track.id, project: &project)
    }

    // MARK: - 删除片段

    /// 从时间线删除片段
    public func removeClip(
        clipId: String,
        project: inout VlogProject
    ) {
        for i in 0..<project.timeline.tracks.count {
            project.timeline.tracks[i].clips.removeAll { $0.id == clipId }
        }
        reindexAllClips(project: &project)
    }

    // MARK: - 重排序

    /// 移动片段到同轨道新位置
    public func moveClip(
        clipId: String,
        to newIndex: Int,
        project: inout VlogProject
    ) throws {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        let clip = project.timeline.tracks[trackIndex].clips.remove(at: clipIndex)
        let clampedIndex = max(0, min(newIndex, project.timeline.tracks[trackIndex].clips.count))
        project.timeline.tracks[trackIndex].clips.insert(clip, at: clampedIndex)
        reindexClips(trackIndex: trackIndex, project: &project)
    }

    /// 移动片段到另一个轨道
    public func moveClip(
        clipId: String,
        toTrack targetTrackId: String,
        project: inout VlogProject
    ) throws {
        guard let (sourceTrackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        guard let targetTrackIndex = project.timeline.tracks.firstIndex(where: { $0.id == targetTrackId }) else {
            throw TimelineServiceError.trackNotFound(id: targetTrackId)
        }

        var clip = project.timeline.tracks[sourceTrackIndex].clips.remove(at: clipIndex)
        clip.trackId = targetTrackId
        clip.order = project.timeline.tracks[targetTrackIndex].clips.count
        project.timeline.tracks[targetTrackIndex].clips.append(clip)

        reindexClips(trackIndex: sourceTrackIndex, project: &project)
        reindexClips(trackIndex: targetTrackIndex, project: &project)
    }

    /// 设置片段音量倍率
    public func setVolume(
        clipId: String,
        volume: Double,
        project: inout VlogProject
    ) throws {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        project.timeline.tracks[trackIndex].clips[clipIndex].volume = min(max(volume, 0), 3)
    }

    /// 设置片段在时间线上的起始时间
    public func setStartTime(
        clipId: String,
        startTime: Double,
        project: inout VlogProject
    ) throws {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        let desiredStart = max(0, startTime)
        project.timeline.tracks[trackIndex].clips[clipIndex].startTime = nonOverlappingStartTime(
            desiredStart,
            clipIndex: clipIndex,
            trackIndex: trackIndex,
            project: project
        )
        reindexClips(trackIndex: trackIndex, project: &project)
    }

    /// 在 clip 内的相对时间切分片段
    @discardableResult
    public func splitClip(
        clipId: String,
        atRelativeTime relativeTime: Double,
        project: inout VlogProject
    ) throws -> TimelineClip {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        let clip = project.timeline.tracks[trackIndex].clips[clipIndex]
        guard relativeTime > 0, relativeTime < clip.duration else {
            throw TimelineServiceError.invalidInPoint
        }

        let splitSourceTime = clip.inPoint + relativeTime
        project.timeline.tracks[trackIndex].clips[clipIndex].outPoint = splitSourceTime

        var right = clip
        right.id = UUID().uuidString
        right.inPoint = splitSourceTime
        right.startTime = clip.startTime + relativeTime
        right.order = clip.order + 1
        project.timeline.tracks[trackIndex].clips.insert(right, at: clipIndex + 1)
        reindexClips(trackIndex: trackIndex, project: &project)
        return right
    }

    // MARK: - 裁剪

    /// 设置片段入点
    public func setInPoint(
        clipId: String,
        inPoint: Double,
        project: inout VlogProject
    ) throws {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        let clip = project.timeline.tracks[trackIndex].clips[clipIndex]
        guard inPoint >= 0 && inPoint < clip.outPoint else {
            throw TimelineServiceError.invalidInPoint
        }
        project.timeline.tracks[trackIndex].clips[clipIndex].inPoint = inPoint
    }

    /// 设置片段出点
    public func setOutPoint(
        clipId: String,
        outPoint: Double,
        project: inout VlogProject
    ) throws {
        guard let (trackIndex, clipIndex) = findClip(clipId: clipId, project: project) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }
        let clip = project.timeline.tracks[trackIndex].clips[clipIndex]
        guard outPoint > clip.inPoint else {
            throw TimelineServiceError.invalidOutPoint
        }
        let maxDuration = project.mediaItems
            .first(where: { $0.id == clip.mediaItemId })?.duration ?? outPoint
        project.timeline.tracks[trackIndex].clips[clipIndex].outPoint = min(outPoint, maxDuration)
    }

    // MARK: - 查询

    /// 获取时间线总时长
    public func totalDuration(project: VlogProject) -> Double {
        project.timeline.totalDuration
    }

    /// 获取指定轨道排序后的片段
    public func sortedClips(trackId: String, project: VlogProject) -> [TimelineClip] {
        project.timeline.tracks
            .first { $0.id == trackId }?
            .sortedClips ?? []
    }

    /// 获取所有视频轨道排序后的片段
    public func sortedVideoClips(project: VlogProject) -> [TimelineClip] {
        project.timeline.videoTrack?.sortedClips ?? []
    }

    /// 根据 clipId 查找对应的 MediaItem
    public func mediaItem(
        forClip clip: TimelineClip,
        project: VlogProject
    ) -> MediaItem? {
        project.mediaItems.first { $0.id == clip.mediaItemId }
    }

    /// 查找 clip 所在的轨道索引和 clip 索引
    private func findClip(
        clipId: String,
        project: VlogProject
    ) -> (trackIndex: Int, clipIndex: Int)? {
        for (ti, track) in project.timeline.tracks.enumerated() {
            if let ci = track.clips.firstIndex(where: { $0.id == clipId }) {
                return (ti, ci)
            }
        }
        return nil
    }

    private func nextStartTime(forTrackIndex trackIndex: Int, project: VlogProject) -> Double {
        project.timeline.tracks[trackIndex].clips.map(\.endTime).max() ?? 0
    }

    /// 视频轨不允许片段重叠：将目标 startTime 夹在前一个片段结束和后一个片段开始之间。
    /// 非视频轨暂时允许重叠，便于后续做音频/字幕叠加。
    private func nonOverlappingStartTime(
        _ desiredStart: Double,
        clipIndex: Int,
        trackIndex: Int,
        project: VlogProject
    ) -> Double {
        let track = project.timeline.tracks[trackIndex]
        guard track.type == .video else { return desiredStart }

        let clip = track.clips[clipIndex]
        let duration = clip.duration
        guard duration > 0 else { return desiredStart }

        let others = track.clips
            .enumerated()
            .filter { $0.offset != clipIndex }
            .map(\.element)
            .sorted { $0.startTime < $1.startTime }

        let previousEnd = others
            .filter { $0.startTime <= desiredStart }
            .map(\.endTime)
            .max() ?? 0

        let nextStart = others
            .filter { $0.startTime >= desiredStart }
            .map(\.startTime)
            .min()

        if let nextStart, nextStart - previousEnd < duration {
            return clip.startTime
        }

        var clamped = max(desiredStart, previousEnd)
        if let nextStart {
            clamped = min(clamped, nextStart - duration)
        }
        return max(0, clamped)
    }

    /// 生成时间线导出计划（视频轨道）
    public func generateExportPlan(
        project: VlogProject,
        projectRoot: URL
    ) -> FFmpegExportPlan? {
        let clips = sortedVideoClips(project: project)
        guard !clips.isEmpty else { return nil }

        var segments: [FFmpegExportSegment] = []
        for clip in clips {
            guard let mediaItem = mediaItem(forClip: clip, project: project) else {
                continue
            }
            let sourceURL = projectRoot.appendingPathComponent(mediaItem.projectRelativePath)
            segments.append(FFmpegExportSegment(
                sourcePath: sourceURL.path,
                inPoint: clip.inPoint,
                outPoint: clip.outPoint,
                volume: clip.volume
            ))
        }

        guard !segments.isEmpty else { return nil }

        let outputURL = projectRoot.appendingPathComponent(project.exportSettings.outputPath)
        return FFmpegExportPlan(
            segments: segments,
            outputPath: outputURL.path,
            resolution: project.resolution,
            videoCodec: project.exportSettings.videoCodec,
            audioCodec: project.exportSettings.audioCodec
        )
    }

    // MARK: - 内部

    private func reindexTracks(project: inout VlogProject) {
        for i in 0..<project.timeline.tracks.count {
            project.timeline.tracks[i].order = i
        }
    }

    private func reindexClips(trackIndex: Int, project: inout VlogProject) {
        for i in 0..<project.timeline.tracks[trackIndex].clips.count {
            project.timeline.tracks[trackIndex].clips[i].order = i
        }
    }

    private func reindexAllClips(project: inout VlogProject) {
        for ti in 0..<project.timeline.tracks.count {
            reindexClips(trackIndex: ti, project: &project)
        }
    }

    private func defaultTrackName(type: TrackType, project: VlogProject) -> String {
        let existingCount = project.timeline.tracks.filter { $0.type == type }.count
        switch type {
        case .video:
            return existingCount == 0 ? "主视频" : "视频 \(existingCount + 1)"
        case .audio:
            return "音频 \(existingCount + 1)"
        case .subtitle:
            return "字幕 \(existingCount + 1)"
        }
    }
}

// MARK: - FFmpeg 导出计划

/// FFmpeg 导出片段
public struct FFmpegExportSegment: Sendable {
    public let sourcePath: String
    public let inPoint: Double
    public let outPoint: Double
    public let volume: Double

    public init(sourcePath: String, inPoint: Double, outPoint: Double, volume: Double = 1.0) {
        self.sourcePath = sourcePath
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.volume = volume
    }

    public var duration: Double {
        max(0, outPoint - inPoint)
    }
}

/// FFmpeg 导出计划
public struct FFmpegExportPlan: Sendable {
    public let segments: [FFmpegExportSegment]
    public let outputPath: String
    public let resolution: Resolution
    public let videoCodec: String
    public let audioCodec: String

    /// 生成 FFmpeg concat 文件内容
    public var concatFileContent: String {
        var lines: [String] = []
        for seg in segments {
            lines.append("file '\(seg.sourcePath)'")
            lines.append("inpoint \(String(format: "%.3f", seg.inPoint))")
            lines.append("outpoint \(String(format: "%.3f", seg.outPoint))")
        }
        return lines.joined(separator: "\n")
    }

    /// 生成 FFmpeg 命令行参数
    public var ffmpegArguments: [String] {
        var args: [String] = []

        for seg in segments {
            args += ["-i", seg.sourcePath]
        }

        // 构建 filter_complex 拼接
        if segments.count > 1 {
            var filterParts: [String] = []
            for i in 0..<segments.count {
                let trim = "trim=start=\(segIn(i)):end=\(segOut(i)),setpts=PTS-STARTPTS"
                filterParts.append("[\(i):v]\(trim)[v\(i)]")
                let atrim = "atrim=start=\(segIn(i)):end=\(segOut(i)),asetpts=PTS-STARTPTS"
                filterParts.append("[\(i):a]\(atrim)[a\(i)]")
            }
            let concatInputs = segments.enumerated().map { "[v\($0)][a\($0)]" }.joined()
            filterParts.append("\(concatInputs)concat=n=\(segments.count):v=1:a=1[outv][outa]")
            args += ["-filter_complex", filterParts.joined(separator: ";")]
            args += ["-map", "[outv]", "-map", "[outa]"]
        } else {
            let seg = segments[0]
            args += ["-ss", String(format: "%.3f", seg.inPoint)]
            args += ["-to", String(format: "%.3f", seg.outPoint)]
        }

        args += ["-c:v", videoCodec, "-c:a", audioCodec]
        args += ["-preset", "medium", "-crf", "23"]
        args += ["-y", outputPath]

        return args
    }

    private func segIn(_ i: Int) -> String {
        String(format: "%.3f", segments[i].inPoint)
    }

    private func segOut(_ i: Int) -> String {
        String(format: "%.3f", segments[i].outPoint)
    }
}
