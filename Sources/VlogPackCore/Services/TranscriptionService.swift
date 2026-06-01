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

    /// 从时间线生成字幕（只读 project，返回字幕文档）
    public func transcribeFromTimeline(
        project: VlogProject,
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

        // 2. 直接逐段精确裁剪音频并拼接为 timeline.wav。
        // 不再先用 -c:v copy 裁视频：按关键帧裁剪会引入时间偏移，导致字幕与预览不对齐。
        let tempDir = projectRoot.appendingPathComponent("cache/temp")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let audioOutput = projectRoot.appendingPathComponent("cache/audio/timeline.wav")
        let audioDir = audioOutput.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        var trimmedAudioPaths: [String] = []
        for (i, seg) in plan.segments.enumerated() {
            let trimmedURL = tempDir.appendingPathComponent(String(format: "whisper_audio_%03d.wav", i))
            let args = [
                "-ss", String(format: "%.3f", seg.inPoint),
                "-i", seg.sourcePath,
                "-t", String(format: "%.3f", seg.duration),
                "-vn",
                "-ac", "1",
                "-ar", "16000",
                "-c:a", "pcm_s16le",
                "-y", trimmedURL.path
            ]
            let result = try ffmpeg.execute(arguments: args)
            guard result.success else {
                throw TranscriptionServiceError.audioExtractionFailed
            }
            trimmedAudioPaths.append(trimmedURL.path)
        }

        if trimmedAudioPaths.count == 1 {
            try? FileManager.default.removeItem(at: audioOutput)
            try FileManager.default.copyItem(atPath: trimmedAudioPaths[0], toPath: audioOutput.path)
        } else {
            let concatURL = tempDir.appendingPathComponent("whisper_audio_concat.txt")
            let concatContent = trimmedAudioPaths.map { "file '\($0)'" }.joined(separator: "\n")
            try concatContent.write(to: concatURL, atomically: true, encoding: .utf8)

            let concatResult = try ffmpeg.execute(arguments: [
                "-f", "concat", "-safe", "0",
                "-i", concatURL.path,
                "-c:a", "pcm_s16le",
                "-ar", "16000",
                "-ac", "1",
                "-y", audioOutput.path
            ])
            guard concatResult.success else {
                throw TranscriptionServiceError.audioExtractionFailed
            }
            try? FileManager.default.removeItem(at: concatURL)
        }

        for path in trimmedAudioPaths {
            try? FileManager.default.removeItem(atPath: path)
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

        // 保存字幕 JSON
        let subtitleURL = projectRoot.appendingPathComponent("subtitles/subtitles.json")
        try JSONStore.write(doc, to: subtitleURL)

        return doc
    }
}
