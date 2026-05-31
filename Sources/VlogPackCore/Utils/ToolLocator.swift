import Foundation

/// 外部工具定位器
/// 查找顺序：App Bundle Resources → PATH → 配置路径
public struct ToolLocator: Sendable {

    /// 工具检测结果
    public struct ToolStatus: Sendable {
        public let name: String
        public let found: Bool
        public let path: String?
        public let version: String?
        public let source: ToolSource?

        public var displayVersion: String {
            version ?? "未知版本"
        }
    }

    public enum ToolSource: String, Sendable {
        case appBundle = "App Bundle"
        case homebrew = "Homebrew"
        case system = "系统 PATH"
        case userConfig = "用户配置"
    }

    /// FFmpeg 路径
    public static func locateFFmpeg() -> ToolStatus {
        locate(
            name: "ffmpeg",
            appBundleName: "ffmpeg",
            homebrewPath: "/opt/homebrew/bin/ffmpeg"
        )
    }

    /// FFprobe 路径
    public static func locateFFprobe() -> ToolStatus {
        locate(
            name: "ffprobe",
            appBundleName: "ffprobe",
            homebrewPath: "/opt/homebrew/bin/ffprobe"
        )
    }

    /// whisper.cpp 路径
    public static func locateWhisper() -> ToolStatus {
        locate(
            name: "whisper",
            appBundleName: "whisper-cli",
            homebrewPath: "/opt/homebrew/bin/whisper-cli"
        )
    }

    /// 检查所有必要工具
    public static func checkAll() -> [ToolStatus] {
        [
            locateFFmpeg(),
            locateFFprobe(),
            locateWhisper(),
        ]
    }

    /// 是否所有必要工具都可用（whisper 可选）
    public static var allRequiredAvailable: Bool {
        locateFFmpeg().found && locateFFprobe().found
    }

    /// 获取 FFmpeg 路径（供 FFmpegAdapter 使用）
    public static func ffmpegPath() -> String {
        locateFFmpeg().path ?? "/opt/homebrew/bin/ffmpeg"
    }

    /// 获取 FFprobe 路径
    public static func ffprobePath() -> String {
        locateFFprobe().path ?? "/opt/homebrew/bin/ffprobe"
    }

    /// 获取 whisper 路径
    public static func whisperPath() -> String {
        locateWhisper().path ?? "/opt/homebrew/bin/whisper-cli"
    }

    // MARK: - Internal

    private static func locate(
        name: String,
        appBundleName: String,
        homebrewPath: String
    ) -> ToolStatus {
        // 1. App Bundle 内置
        if let bundlePath = findInAppBundle(name: appBundleName) {
            let version = getVersion(bundlePath)
            return ToolStatus(
                name: name,
                found: true,
                path: bundlePath,
                version: version,
                source: .appBundle
            )
        }

        // 2. Homebrew 路径
        if FileManager.default.fileExists(atPath: homebrewPath) {
            let version = getVersion(homebrewPath)
            return ToolStatus(
                name: name,
                found: true,
                path: homebrewPath,
                version: version,
                source: .homebrew
            )
        }

        // 3. PATH 查找
        if let pathInPATH = findInPATH(name: name) {
            let version = getVersion(pathInPATH)
            return ToolStatus(
                name: name,
                found: true,
                path: pathInPATH,
                version: version,
                source: .system
            )
        }

        return ToolStatus(
            name: name,
            found: false,
            path: nil,
            version: nil,
            source: nil
        )
    }

    private static func findInAppBundle(name: String) -> String? {
        // 检查是否在 App Bundle 的 Resources 目录中
        guard let bundlePath = Bundle.main.resourcePath else { return nil }
        let fullPath = (bundlePath as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
    }

    private static func findInPATH(name: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == true) ? nil : path
        } catch {
            return nil
        }
    }

    private static func getVersion(_ path: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-version"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // 提取版本号（取第一行）
            let firstLine = output.components(separatedBy: .newlines).first ?? ""
            return firstLine.isEmpty ? nil : firstLine
        } catch {
            return nil
        }
    }
}
