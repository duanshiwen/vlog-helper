import Foundation

/// 首次启动设置服务
/// 追踪外部工具可用性和首次运行状态
public final class SetupService: @unchecked Sendable {
    private let stateURL: URL

    /// 设置状态
    public struct SetupState: Codable, Sendable {
        public var hasCompletedSetup: Bool
        public var ffmpegAvailable: Bool
        public var whisperAvailable: Bool
        public var lastCheckedAt: Date?

        public init() {
            self.hasCompletedSetup = false
            self.ffmpegAvailable = false
            self.whisperAvailable = false
            self.lastCheckedAt = nil
        }
    }

    public init(configDir: URL? = nil) {
        let base = configDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vlogpack")
        self.stateURL = base.appendingPathComponent("setup-state.json")
    }

    /// 加载或创建默认状态
    public func loadState() -> SetupState {
        guard let data = try? Data(contentsOf: stateURL) else {
            return SetupState()
        }
        return (try? JSONDecoder().decode(SetupState.self, from: data)) ?? SetupState()
    }

    /// 保存状态
    public func saveState(_ state: SetupState) throws {
        let dir = stateURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder.prettyEncoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    /// 刷新工具可用性
    public func refreshToolStatus() -> SetupState {
        var state = loadState()
        state.ffmpegAvailable = FFmpegAdapter().checkAvailability()
        state.whisperAvailable = WhisperAdapter().checkAvailability()
        state.lastCheckedAt = Date()
        try? saveState(state)
        return state
    }

    /// 标记设置完成
    public func markSetupComplete() {
        var state = loadState()
        state.hasCompletedSetup = true
        state.lastCheckedAt = Date()
        try? saveState(state)
    }

    /// 是否需要显示设置向导
    public var needsSetup: Bool {
        let state = loadState()
        if !state.hasCompletedSetup { return true }
        // 每次启动都检查 FFmpeg
        return !FFmpegAdapter().checkAvailability()
    }
}

// MARK: - JSONEncoder Extension

extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
