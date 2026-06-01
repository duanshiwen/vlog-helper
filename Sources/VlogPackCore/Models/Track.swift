import Foundation

/// 轨道类型
public enum TrackType: String, Codable, Sendable, CaseIterable {
    case video
    case audio
    case subtitle

    public var displayName: String {
        switch self {
        case .video:    return "视频"
        case .audio:    return "音频"
        case .subtitle: return "字幕"
        }
    }

    public var iconName: String {
        switch self {
        case .video:    return "film"
        case .audio:    return "speaker.wave.2"
        case .subtitle: return "text.bubble"
        }
    }

    /// 是否允许多个轨道
    public var allowsMultiple: Bool {
        switch self {
        case .video:    return false  // 主视频轨唯一
        case .audio:    return true
        case .subtitle: return true
        }
    }
}

/// 轨道
public struct Track: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var type: TrackType
    public var clips: [TimelineClip]
    public var isMuted: Bool
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: TrackType,
        clips: [TimelineClip] = [],
        isMuted: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.clips = clips
        self.isMuted = isMuted
        self.order = order
    }

    /// 按 order 排序后的片段
    public var sortedClips: [TimelineClip] {
        clips.sorted { $0.order < $1.order }
    }

    /// 轨道总时长（秒）
    public var totalDuration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }
}
