import Foundation

/// Whisper 转写结果
public struct WhisperResult: Sendable {
    public let segments: [WhisperSegment]
    public let rawText: String

    public init(segments: [WhisperSegment], rawText: String) {
        self.segments = segments
        self.rawText = rawText
    }
}

/// Whisper 单段转写
public struct WhisperSegment: Sendable {
    public let start: Double
    public let end: Double
    public let text: String

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

/// Whisper 适配器
public final class WhisperAdapter: @unchecked Sendable {
    public let whisperPath: String
    public let modelPath: String

    public init(
        whisperPath: String? = nil,
        modelPath: String? = nil
    ) {
        self.whisperPath = whisperPath ?? Self.resolveWhisperPath()
        self.modelPath = modelPath ?? Self.defaultModelPath()
    }

    /// 默认模型路径: ~/.vlogpack/whisper-models/ggml-base.bin
    private static func defaultModelPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".vlogpack/whisper-models/ggml-base.bin").path
    }

    /// 解析 whisper 路径（不查 Bundle，因为依赖动态库无法单独运行）
    private static func resolveWhisperPath() -> String {
        // 环境变量优先
        if let envPath = ProcessInfo.processInfo.environment["WHISPER_PATH"], !envPath.isEmpty {
            return envPath
        }
        // 系统已安装路径
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cli"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/opt/homebrew/bin/whisper-cli"
    }

    /// 检查 whisper 是否可用（二进制 + 模型都存在）
    public func checkAvailability() -> Bool {
        let binaryOK = FileManager.default.fileExists(atPath: whisperPath)
        let modelOK = FileManager.default.fileExists(atPath: modelPath)
        return binaryOK && modelOK
    }

    /// 仅检查二进制是否可用
    public func checkBinaryAvailable() -> Bool {
        FileManager.default.fileExists(atPath: whisperPath)
    }

    /// 仅检查模型是否可用
    public func checkModelAvailable() -> Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    /// 执行转写
    public func transcribe(
        audioPath: String,
        language: String = "zh",
        outputDir: String
    ) throws -> WhisperResult {
        var args = [
            "-m", modelPath,
            "-f", audioPath,
            "-l", language,
            "-oj",  // output JSON
            "-of", outputDir + "/whisper_output",
            "--output-srt",
            "--no-prints",
        ]

        // 如果模型路径为空，使用自动检测
        if modelPath.isEmpty {
            args = [
                "-f", audioPath,
                "-l", language,
                "-oj",
                "-of", outputDir + "/whisper_output",
                "--output-srt",
                "--no-prints",
            ]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus

            // 提供更友好的错误信息
            let hint: String
            if !FileManager.default.fileExists(atPath: modelPath) {
                hint = "模型文件不存在: \(modelPath)，请在设置页下载模型"
            } else if exitCode == 2 {
                hint = "参数错误或模型加载失败，请检查模型文件是否完整"
            } else if exitCode == 137 {
                hint = "进程被杀死（内存不足？）"
            } else {
                hint = stderr.isEmpty ? "未知错误" : stderr
            }
            throw WhisperError.transcriptionFailed(details: "whisper-cli 退出码 \(exitCode): \(hint)")
        }

        // 解析 JSON 输出
        let jsonPath = outputDir + "/whisper_output.json"
        return try parseOutput(jsonPath: jsonPath)
    }

    private func parseOutput(jsonPath: String) throws -> WhisperResult {
        let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let segments = json?["transcription"] as? [[String: Any]] else {
            throw WhisperError.invalidOutput
        }

        var whisperSegments: [WhisperSegment] = []
        for seg in segments {
            let start = seg["timestamps"] as? [Any]
            let t0 = (start?.first as? Double) ?? (seg["start"] as? Double) ?? 0
            let t1 = (start?.last as? Double) ?? (seg["end"] as? Double) ?? 0
            let text = (seg["text"] as? String) ?? ""
            whisperSegments.append(WhisperSegment(start: t0, end: t1, text: text.trimmingCharacters(in: .whitespaces)))
        }

        let rawText = whisperSegments.map(\.text).joined(separator: " ")
        return WhisperResult(segments: whisperSegments, rawText: rawText)
    }
}

/// Whisper 错误
public enum WhisperError: Error, Sendable {
    case transcriptionFailed(details: String)
    case invalidOutput
    case whisperNotAvailable
}
