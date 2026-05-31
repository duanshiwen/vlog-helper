import Foundation

/// 时间线服务错误
public enum TimelineServiceError: Error, Sendable {
    case mediaItemNotFound(id: String)
    case invalidInPoint
    case invalidOutPoint
    case clipNotFound(id: String)
}

/// 时间线服务
public final class TimelineService: @unchecked Sendable {
    public init() {}

    // MARK: - 添加片段

    /// 将素材添加到时间线末尾
    @discardableResult
    public func addClip(
        mediaItemId: String,
        project: inout VlogProject
    ) throws -> TimelineClip {
        guard let mediaItem = project.mediaItems.first(where: { $0.id == mediaItemId }) else {
            throw TimelineServiceError.mediaItemNotFound(id: mediaItemId)
        }

        let clip = TimelineClip(
            mediaItemId: mediaItemId,
            inPoint: 0,
            outPoint: mediaItem.duration > 0 ? mediaItem.duration : 0,
            order: project.timeline.clips.count
        )
        project.timeline.clips.append(clip)
        return clip
    }

    // MARK: - 删除片段

    /// 从时间线删除片段
    public func removeClip(
        clipId: String,
        project: inout VlogProject
    ) {
        project.timeline.clips.removeAll { $0.id == clipId }
        reindexClips(project: &project)
    }

    // MARK: - 重排序

    /// 移动片段到新位置
    public func moveClip(
        clipId: String,
        to newIndex: Int,
        project: inout VlogProject
    ) throws {
        guard let currentIndex = project.timeline.clips.firstIndex(where: { $0.id == clipId }) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }

        let clip = project.timeline.clips.remove(at: currentIndex)
        let clampedIndex = max(0, min(newIndex, project.timeline.clips.count))
        project.timeline.clips.insert(clip, at: clampedIndex)
        reindexClips(project: &project)
    }

    // MARK: - 裁剪

    /// 设置片段入点
    public func setInPoint(
        clipId: String,
        inPoint: Double,
        project: inout VlogProject
    ) throws {
        guard let index = project.timeline.clips.firstIndex(where: { $0.id == clipId }) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }

        let clip = project.timeline.clips[index]
        guard inPoint >= 0 && inPoint < clip.outPoint else {
            throw TimelineServiceError.invalidInPoint
        }

        project.timeline.clips[index].inPoint = inPoint
    }

    /// 设置片段出点
    public func setOutPoint(
        clipId: String,
        outPoint: Double,
        project: inout VlogProject
    ) throws {
        guard let index = project.timeline.clips.firstIndex(where: { $0.id == clipId }) else {
            throw TimelineServiceError.clipNotFound(id: clipId)
        }

        let clip = project.timeline.clips[index]
        guard outPoint > clip.inPoint else {
            throw TimelineServiceError.invalidOutPoint
        }

        // 限制不超过素材时长
        let maxDuration = project.mediaItems
            .first(where: { $0.id == clip.mediaItemId })?.duration ?? outPoint
        project.timeline.clips[index].outPoint = min(outPoint, maxDuration)
    }

    // MARK: - 查询

    /// 获取时间线总时长
    public func totalDuration(project: VlogProject) -> Double {
        project.timeline.totalDuration
    }

    /// 获取时间线排序后的片段
    public func sortedClips(project: VlogProject) -> [TimelineClip] {
        project.timeline.sortedClips
    }

    /// 根据 clipId 查找对应的 MediaItem
    public func mediaItem(
        forClip clip: TimelineClip,
        project: VlogProject
    ) -> MediaItem? {
        project.mediaItems.first { $0.id == clip.mediaItemId }
    }

    /// 生成时间线预览的 FFmpeg concat 参数
    public func generateExportPlan(
        project: VlogProject,
        projectRoot: URL
    ) -> FFmpegExportPlan? {
        let clips = project.timeline.sortedClips
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
                outPoint: clip.outPoint
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

    private func reindexClips(project: inout VlogProject) {
        for i in 0..<project.timeline.clips.count {
            project.timeline.clips[i].order = i
        }
    }
}

// MARK: - FFmpeg 导出计划

/// FFmpeg 导出片段
public struct FFmpegExportSegment: Sendable {
    public let sourcePath: String
    public let inPoint: Double
    public let outPoint: Double

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
