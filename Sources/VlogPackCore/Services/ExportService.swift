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

        // 使用 concat demuxer 方式（更可靠）
        let concatFileURL = projectRoot.appendingPathComponent("cache/temp/concat.txt")
        try plan.concatFileContent.write(
            to: concatFileURL,
            atomically: true,
            encoding: .utf8
        )

        let args = [
            "-f", "concat",
            "-safe", "0",
            "-i", concatFileURL.path,
            "-c:v", plan.videoCodec,
            "-c:a", plan.audioCodec,
            "-preset", "medium",
            "-crf", "23",
            "-movflags", "+faststart",
            "-y", plan.outputPath
        ]

        let result = try ffmpeg.executeWithProgress(
            arguments: args,
            onProgress: onProgress
        )

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
