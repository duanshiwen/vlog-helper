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

    /// 默认模型路径: 优先 large-v3 > medium > small > base
    private static func defaultModelPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let modelsDir = home.appendingPathComponent(".vlogpack/whisper-models")
        // 按优先级查找已下载的模型
        let candidates = ["ggml-large-v3.bin", "ggml-medium.bin", "ggml-small.bin", "ggml-base.bin", "ggml-tiny.bin"]
        for name in candidates {
            let path = modelsDir.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 兜底返回 large-v3（即使不存在，给用户明确提示）
        return modelsDir.appendingPathComponent("ggml-large-v3.bin").path
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
            "--beam-size", "5",
            "--best-of", "5",
            "--entropy-thold", "2.4",
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

        // 繁体 → 简体转换
        let convertedPath = outputDir + "/whisper_output_s.json"
        if convertTraditionalToSimplified(jsonPath: jsonPath, outputPath: convertedPath) {
            return try parseOutput(jsonPath: convertedPath)
        }
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
            let text = (seg["text"] as? String) ?? ""
            let trimmedText = text.trimmingCharacters(in: .whitespaces)
            if trimmedText.isEmpty { continue }

            // whisper-cli 输出格式: timestamps: { from: "HH:MM:SS,mmm", to: "HH:MM:SS,mmm" }
            let t0: Double
            let t1: Double
            if let timestamps = seg["timestamps"] as? [String: Any],
               let fromStr = timestamps["from"] as? String,
               let toStr = timestamps["to"] as? String {
                t0 = Self.parseTimestamp(fromStr)
                t1 = Self.parseTimestamp(toStr)
            } else if let offsets = seg["offsets"] as? [String: Any],
                      let fromMs = offsets["from"] as? Int,
                      let toMs = offsets["to"] as? Int {
                t0 = Double(fromMs) / 1000.0
                t1 = Double(toMs) / 1000.0
            } else {
                continue
            }

            whisperSegments.append(WhisperSegment(start: t0, end: t1, text: trimmedText))
        }

        let rawText = whisperSegments.map(\.text).joined(separator: " ")
        return WhisperResult(segments: whisperSegments, rawText: rawText)
    }

    /// 繁体 → 简体转换（调用 Python opencc）
    private func convertTraditionalToSimplified(jsonPath: String, outputPath: String) -> Bool {
        // 查找 t2s.py 脚本
        let scriptPath = findT2SScript() ?? ""
        guard !scriptPath.isEmpty else { return false }

        // 查找 Python
        let pythonPath = findPython() ?? ""
        guard !pythonPath.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, jsonPath, outputPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputPath)
        } catch {
            return false
        }
    }

    private func findT2SScript() -> String? {
        let candidates: [String?] = [
            Bundle.main.path(forResource: "t2s", ofType: "py"),
            Bundle.main.bundlePath + "/Contents/MacOS/t2s.py",
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("t2s.py").path,
        ]
        for candidate in candidates {
            if let path = candidate, FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // 开发环境: 项目根/scripts/t2s.py
        let devPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/t2s.py").path
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        return nil
    }

    private func findPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
            Bundle.main.bundlePath + "/Contents/MacOS/t2s-venv/bin/python3",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// 解析 whisper-cli 时间戳格式: "HH:MM:SS,mmm" -> 秒
    private static func parseTimestamp(_ str: String) -> Double {
        // 格式: "00:01:23,456"
        let parts = str.split(separator: ":")
        guard parts.count == 3 else { return 0 }
        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secParts = parts[2].split(separator: ",")
        let seconds = Double(secParts[0]) ?? 0
        let ms = secParts.count > 1 ? (Double(secParts[1]) ?? 0) : 0
        return hours * 3600 + minutes * 60 + seconds + ms / 1000.0
    }
}

/// Whisper 错误
public enum WhisperError: Error, Sendable {
    case transcriptionFailed(details: String)
    case invalidOutput
    case whisperNotAvailable
}
