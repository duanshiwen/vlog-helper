import Foundation

/// 转写服务错误
public enum TranscriptionServiceError: Error, Sendable {
    case noClips
    case whisperNotAvailable
    case audioExtractionFailed
    case transcriptionFailed(details: String)
}

/// 转写服务：协调时间线 → 音频提取 → whisper 转写 → 字幕格式转换
public final class TranscriptionService: @unchecked Sendable {
    private let ffmpeg: FFmpegAdapter
    private let whisper: WhisperAdapter

    public init(
        ffmpeg: FFmpegAdapter = FFmpegAdapter(),
        whisper: WhisperAdapter = WhisperAdapter()
    ) {
        self.ffmpeg = ffmpeg
        self.whisper = whisper
    }

    // MARK: - 执行转写

    /// 从时间线生成字幕
    public func transcribeFromTimeline(
        project: inout VlogProject,
        projectRoot: URL,
        language: String = "zh"
    ) throws -> SubtitleDocument {
        guard whisper.checkAvailability() else {
            throw TranscriptionServiceError.whisperNotAvailable
        }

        // 1. 生成 concat 文件
        let timelineService = TimelineService()
        guard let plan = timelineService.generateExportPlan(
            project: project,
            projectRoot: projectRoot
        ) else {
            throw TranscriptionServiceError.noClips
        }

        // 2. 逐个裁切片段并拼接为临时视频
        let tempDir = projectRoot.appendingPathComponent("cache/temp")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var trimmedPaths: [String] = []
        for (i, seg) in plan.segments.enumerated() {
            let trimmedURL = tempDir.appendingPathComponent(String(format: "whisper_trimmed_%03d.mp4", i))
            let args = [
                "-ss", String(format: "%.3f", seg.inPoint),
                "-i", seg.sourcePath,
                "-to", String(format: "%.3f", seg.duration),
                "-c:v", "copy", "-c:a", "aac",
                "-y", trimmedURL.path
            ]
            let result = try ffmpeg.execute(arguments: args)
            guard result.success else {
                throw TranscriptionServiceError.audioExtractionFailed
            }
            trimmedPaths.append(trimmedURL.path)
        }

        // 拼接裁切后的片段
        let tempVideo = projectRoot.appendingPathComponent("cache/temp/whisper_temp.mp4")
        if trimmedPaths.count == 1 {
            try FileManager.default.copyItem(
                atPath: trimmedPaths[0],
                toPath: tempVideo.path
            )
        } else {
            let concatURL = tempDir.appendingPathComponent("whisper_concat.txt")
            let concatContent = trimmedPaths.map { "file '\($0)'" }.joined(separator: "\n")
            try concatContent.write(to: concatURL, atomically: true, encoding: .utf8)

            let concatResult = try ffmpeg.execute(arguments: [
                "-f", "concat", "-safe", "0",
                "-i", concatURL.path,
                "-c:v", "copy", "-c:a", "aac",
                "-y", tempVideo.path
            ])
            guard concatResult.success else {
                throw TranscriptionServiceError.audioExtractionFailed
            }
            try? FileManager.default.removeItem(at: concatURL)
        }

        // 清理裁切临时文件
        for path in trimmedPaths {
            try? FileManager.default.removeItem(atPath: path)
        }

        // 3. 提取 16kHz 单声道 WAV（whisper 要求）
        let audioOutput = projectRoot.appendingPathComponent("cache/audio/timeline.wav")
        let audioDir = audioOutput.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let audioResult = try ffmpeg.extractAudio(
            fromVideoPath: tempVideo.path,
            outputPath: audioOutput.path
        )

        guard audioResult.success else {
            throw TranscriptionServiceError.audioExtractionFailed
        }

        // 清理临时视频
        try? FileManager.default.removeItem(at: tempVideo)

        // 3. 调用 whisper 转写
        let whisperResult = try whisper.transcribe(
            audioPath: audioOutput.path,
            language: language,
            outputDir: projectRoot.appendingPathComponent("cache/transcription").path
        )

        // 4. 转换为 SubtitleDocument
        let segments = whisperResult.segments.map { seg in
            SubtitleSegment(
                start: seg.start,
                end: seg.end,
                text: seg.text
            )
        }

        let doc = SubtitleDocument(segments: segments)
        project.subtitles = doc

        // 保存字幕 JSON
        let subtitleURL = projectRoot.appendingPathComponent("subtitles/subtitles.json")
        try JSONStore.write(doc, to: subtitleURL)

        return doc
    }
}
