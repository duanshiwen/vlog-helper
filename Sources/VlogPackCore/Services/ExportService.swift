import Foundation

/// 导出服务错误
public enum ExportServiceError: Error, Sendable {
    case noClips
    case ffmpegNotAvailable
    case exportFailed(details: String)
}

/// 导出服务
public final class ExportService: @unchecked Sendable {
    private let ffmpeg: FFmpegAdapter
    private let timelineService: TimelineService

    public init(
        ffmpeg: FFmpegAdapter = FFmpegAdapter(),
        timelineService: TimelineService = TimelineService()
    ) {
        self.ffmpeg = ffmpeg
        self.timelineService = timelineService
    }

    // MARK: - 导出无字幕视频

    /// 根据时间线导出无字幕视频
    public func exportNoSubtitle(
        project: VlogProject,
        projectRoot: URL,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) throws -> String {
        guard ffmpeg.checkAvailability() else {
            throw ExportServiceError.ffmpegNotAvailable
        }

        guard let plan = timelineService.generateExportPlan(
            project: project,
            projectRoot: projectRoot
        ) else {
            throw ExportServiceError.noClips
        }

        // 确保输出目录存在
        let outputURL = URL(fileURLWithPath: plan.outputPath)
        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: outputDir,
            withIntermediateDirectories: true
        )

        let result: FFmpegResult

        if plan.segments.count == 1 {
            // 单片段：直接用 -ss/-to 裁切
            result = try exportSingleSegment(
                segment: plan.segments[0],
                outputPath: plan.outputPath,
                onProgress: onProgress
            )
        } else {
            // 多片段：逐个裁切后拼接
            result = try exportMultiSegments(
                segments: plan.segments,
                projectRoot: projectRoot,
                outputPath: plan.outputPath,
                resolution: plan.resolution,
                onProgress: onProgress
            )
        }

        // 写入日志
        writeExportLog(
            projectRoot: projectRoot,
            type: "no-subtitle",
            result: result
        )

        guard result.success else {
            throw ExportServiceError.exportFailed(details: result.stderr)
        }

        return plan.outputPath
    }

    /// 单片段裁切导出
    private func exportSingleSegment(
        segment: FFmpegExportSegment,
        outputPath: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws -> FFmpegResult {
        var args = [
            "-ss", String(format: "%.3f", segment.inPoint),
            "-i", segment.sourcePath,
            "-to", String(format: "%.3f", segment.duration)
        ]
        if abs(segment.volume - 1.0) > 0.001 {
            args += ["-filter:a", "volume=\(String(format: "%.3f", segment.volume))"]
        }
        args += [
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "23",
            "-c:a", "aac",
            "-movflags", "+faststart",
            "-y", outputPath
        ]
        return try ffmpeg.executeWithProgress(arguments: args, onProgress: onProgress)
    }

    /// 多片段裁切 + 拼接
    private func exportMultiSegments(
        segments: [FFmpegExportSegment],
        projectRoot: URL,
        outputPath: String,
        resolution: Resolution,
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws -> FFmpegResult {
        let tempDir = projectRoot.appendingPathComponent("cache/temp")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 1. 逐个裁切片段
        var trimmedPaths: [String] = []
        for (i, seg) in segments.enumerated() {
            let trimmedURL = tempDir.appendingPathComponent(String(format: "trimmed_%03d.mp4", i))
            var args = [
                "-ss", String(format: "%.3f", seg.inPoint),
                "-i", seg.sourcePath,
                "-to", String(format: "%.3f", seg.duration)
            ]
            if abs(seg.volume - 1.0) > 0.001 {
                args += ["-filter:a", "volume=\(String(format: "%.3f", seg.volume))"]
            }
            args += [
                "-c:v", "libx264",
                "-preset", "medium",
                "-crf", "23",
                "-c:a", "aac",
                "-y", trimmedURL.path
            ]
            let result = try ffmpeg.execute(arguments: args)
            guard result.success else {
                throw ExportServiceError.exportFailed(
                    details: "片段 \(i) 裁切失败: \(result.stderr)"
                )
            }
            trimmedPaths.append(trimmedURL.path)
        }

        // 2. 用 concat demuxer 拼接（已裁切片段，无 inpoint/outpoint）
        let concatURL = tempDir.appendingPathComponent("concat.txt")
        let concatContent = trimmedPaths.map { "file '\($0)'" }.joined(separator: "\n")
        try concatContent.write(to: concatURL, atomically: true, encoding: .utf8)

        let args = [
            "-f", "concat",
            "-safe", "0",
            "-i", concatURL.path,
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "23",
            "-c:a", "aac",
            "-movflags", "+faststart",
            "-y", outputPath
        ]
        let result = try ffmpeg.executeWithProgress(arguments: args, onProgress: onProgress)

        // 3. 清理临时裁切文件
        for path in trimmedPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        try? FileManager.default.removeItem(at: concatURL)

        return result
    }

    // MARK: - 导出带字幕视频

    /// 导出烧录字幕的视频
    public func exportWithSubtitles(
        project: VlogProject,
        projectRoot: URL,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) throws -> String {
        // 先导出无字幕版本
        let noSubPath = try exportNoSubtitle(
            project: project,
            projectRoot: projectRoot
        )

        guard project.subtitles != nil else {
            return noSubPath
        }

        // 导出 ASS 文件
        let subtitleService = SubtitleService()
        let assContent = subtitleService.exportASS(project: project)
        let assURL = projectRoot.appendingPathComponent("subtitles/subtitles.ass")
        try assContent.write(to: assURL, atomically: true, encoding: .utf8)

        // 烧录
        let outputRelative = project.exportSettings.outputPath
        let noSubFull = projectRoot.appendingPathComponent(noSubPath)
        let finalFull = projectRoot.appendingPathComponent(outputRelative)

        let result = try ffmpeg.burnSubtitles(
            videoPath: noSubFull.path,
            subtitlePath: assURL.path,
            outputPath: finalFull.path,
            resolution: project.resolution
        )

        writeExportLog(
            projectRoot: projectRoot,
            type: "with-subtitle",
            result: result
        )

        guard result.success else {
            throw ExportServiceError.exportFailed(details: result.stderr)
        }

        return outputRelative
    }

    // MARK: - 导出字幕文件

    /// 导出 SRT 和 ASS 到 exports/
    public func exportSubtitleFiles(
        project: VlogProject,
        projectRoot: URL
    ) {
        let service = SubtitleService()

        // SRT
        let srt = service.exportSRT(project: project)
        let srtURL = projectRoot.appendingPathComponent("exports/subtitles.srt")
        try? srt.write(to: srtURL, atomically: true, encoding: .utf8)

        // ASS
        let ass = service.exportASS(project: project)
        let assURL = projectRoot.appendingPathComponent("exports/subtitles.ass")
        try? ass.write(to: assURL, atomically: true, encoding: .utf8)
    }

    // MARK: - 日志

    private func writeExportLog(
        projectRoot: URL,
        type: String,
        result: FFmpegResult
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let logContent = """
        Export Type: \(type)
        Timestamp: \(timestamp)
        Exit Code: \(result.exitCode)
        Success: \(result.success)

        --- STDERR ---
        \(result.stderr)
        """

        let logURL = projectRoot.appendingPathComponent("logs/export-\(timestamp).log")
        try? logContent.write(to: logURL, atomically: true, encoding: .utf8)
    }
}
