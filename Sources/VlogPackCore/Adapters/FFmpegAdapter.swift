import Foundation

/// FFmpeg 执行结果
public struct FFmpegResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let success: Bool

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.success = exitCode == 0
    }
}

/// FFmpeg/FFprobe 适配器
public final class FFmpegAdapter: @unchecked Sendable {
    /// ffmpeg 路径
    public let ffmpegPath: String
    /// ffprobe 路径
    public let ffprobePath: String

    public init(
        ffmpegPath: String = "/opt/homebrew/bin/ffmpeg",
        ffprobePath: String = "/opt/homebrew/bin/ffprobe"
    ) {
        self.ffmpegPath = ffmpegPath
        self.ffprobePath = ffprobePath
    }

    // MARK: - 环境检查

    /// 检查 FFmpeg 是否可用
    public func checkAvailability() -> Bool {
        FileManager.default.fileExists(atPath: ffmpegPath)
    }

    // MARK: - 执行 FFmpeg

    /// 执行 FFmpeg 命令
    @discardableResult
    public func execute(arguments: [String]) throws -> FFmpegResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return FFmpegResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    /// 带进度回调的执行（解析 stderr 进度）
    @discardableResult
    public func executeWithProgress(
        arguments: [String],
        onProgress: @escaping @Sendable (Double) -> Void
    ) throws -> FFmpegResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // 异步读取 stderr 以解析进度
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let line = String(data: data, encoding: .utf8) {
                // 解析 time= 部分用于进度估算
                if let timeRange = line.range(of: "time=") {
                    let afterTime = String(line[timeRange.upperBound...])
                    let timeStr = afterTime.prefix(11) // HH:MM:SS.ss
                    if let seconds = self.parseTime(String(timeStr)) {
                        onProgress(seconds)
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return FFmpegResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    // MARK: - FFprobe

    /// 获取视频时长
    public func getVideoDuration(path: String) throws -> Double {
        let args = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            path
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        return Double(output) ?? 0
    }

    // MARK: - 音频提取

    /// 从视频提取音频为 WAV
    public func extractAudio(
        fromVideoPath: String,
        outputPath: String,
        sampleRate: Int = 16000,
        channels: Int = 1
    ) throws -> FFmpegResult {
        let args = [
            "-i", fromVideoPath,
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "\(sampleRate)",
            "-ac", "\(channels)",
            "-y", outputPath
        ]
        return try execute(arguments: args)
    }

    // MARK: - 烧录字幕

    /// 烧录 ASS 字幕到视频
    public func burnSubtitles(
        videoPath: String,
        subtitlePath: String,
        outputPath: String,
        resolution: Resolution
    ) throws -> FFmpegResult {
        // 使用 subtitles filter（支持 ASS）
        let escapedPath = subtitlePath.replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: ":", with: "\\:")
        let filter = "subtitles='\(escapedPath)'"

        let args = [
            "-i", videoPath,
            "-vf", filter,
            "-c:v", "libx264",
            "-preset", "medium",
            "-crf", "23",
            "-c:a", "aac",
            "-y", outputPath
        ]
        return try execute(arguments: args)
    }

    // MARK: - 抽帧

    /// 从视频指定时间点导出帧为图片
    public func extractFrame(
        videoPath: String,
        time: Double,
        outputPath: String,
        maxWidth: Int = 1920
    ) throws -> FFmpegResult {
        let args = [
            "-ss", String(format: "%.3f", time),
            "-i", videoPath,
            "-vframes", "1",
            "-vf", "scale=\(maxWidth):-1",
            "-y", outputPath
        ]
        return try execute(arguments: args)
    }

    // MARK: - 内部

    private func parseTime(_ timeStr: String) -> Double? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 3 else { return nil }
        let h = Double(parts[0]) ?? 0
        let m = Double(parts[1]) ?? 0
        let s = Double(parts[2]) ?? 0
        return h * 3600 + m * 60 + s
    }
}
