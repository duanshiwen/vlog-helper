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
        modelPath: String = ""
    ) {
        self.whisperPath = whisperPath ?? Self.resolvePath("whisper-cli", fallback: "/opt/homebrew/bin/whisper-cli")
        self.modelPath = modelPath
    }

    /// 解析二进制路径
    private static func resolvePath(_ name: String, fallback: String) -> String {
        if let bundlePath = Bundle.main.path(forResource: name, ofType: nil) {
            return bundlePath
        }
        if let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            let candidate = execDir + "/" + name
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        if let envPath = ProcessInfo.processInfo.environment["WHISPER_PATH"], !envPath.isEmpty {
            return envPath
        }
        return fallback
    }

    /// 检查 whisper 是否可用
    public func checkAvailability() -> Bool {
        FileManager.default.fileExists(atPath: whisperPath)
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
            throw WhisperError.transcriptionFailed(details: stderr)
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
