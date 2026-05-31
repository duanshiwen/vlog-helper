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

        let concatFile = projectRoot.appendingPathComponent("cache/temp/whisper_concat.txt")
        try plan.concatFileContent.write(
            to: concatFile,
            atomically: true,
            encoding: .utf8
        )

        // 2. 提取音频为 WAV
        let audioOutput = projectRoot.appendingPathComponent("cache/audio/timeline.wav")
        let audioDir = audioOutput.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        // 先用 concat 生成临时视频再提取音频
        let tempVideo = projectRoot.appendingPathComponent("cache/temp/whisper_temp.mp4")
        let concatResult = try ffmpeg.execute(arguments: [
            "-f", "concat", "-safe", "0",
            "-i", concatFile.path,
            "-c:v", "copy", "-c:a", "aac",
            "-y", tempVideo.path
        ])

        guard concatResult.success else {
            throw TranscriptionServiceError.audioExtractionFailed
        }

        // 提取 16kHz 单声道 WAV（whisper 要求）
        let audioResult = try ffmpeg.extractAudio(
            fromVideoPath: tempVideo.path,
            outputPath: audioOutput.path
        )

        guard audioResult.success else {
            throw TranscriptionServiceError.audioExtractionFailed
        }

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

        // 清理临时文件
        try? FileManager.default.removeItem(at: tempVideo)

        return doc
    }
}
