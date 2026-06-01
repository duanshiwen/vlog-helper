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
        if clips.count > 1 && clips.allSatisfy({ $0.startTime == 0 }) {
            var migrated = clips
            var cursor = 0.0
            for index in migrated.indices.sorted(by: { migrated[$0].order < migrated[$1].order }) {
                migrated[index].startTime = cursor
                cursor += migrated[index].duration
            }
            self.clips = migrated
        } else {
            self.clips = clips
        }
        self.isMuted = isMuted
        self.order = order
    }

    /// 按时间线位置排序后的片段
    public var sortedClips: [TimelineClip] {
        clips.sorted {
            if $0.startTime == $1.startTime { return $0.order < $1.order }
            return $0.startTime < $1.startTime
        }
    }

    /// 轨道总时长（秒）
    public var totalDuration: Double {
        clips.map(\.endTime).max() ?? 0
    }
}
