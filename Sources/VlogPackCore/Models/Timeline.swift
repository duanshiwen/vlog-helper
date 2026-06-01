import Foundation

/// 时间线片段
public struct TimelineClip: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    /// 关联的 MediaItem ID
    public var mediaItemId: String
    /// 所属轨道 ID
    public var trackId: String
    /// 入点（秒）
    public var inPoint: Double
    /// 出点（秒）
    public var outPoint: Double
    /// 在时间线上的起始时间（秒）
    public var startTime: Double
    /// 音量倍率（1.0 = 100%）
    public var volume: Double
    /// 排序序号
    public var order: Int
    /// 字幕文本（仅字幕轨道使用）
    public var subtitleText: String?

    public init(
        id: String = UUID().uuidString,
        mediaItemId: String,
        trackId: String = "",
        inPoint: Double = 0,
        outPoint: Double = 0,
        startTime: Double = 0,
        volume: Double = 1.0,
        order: Int = 0,
        subtitleText: String? = nil
    ) {
        self.id = id
        self.mediaItemId = mediaItemId
        self.trackId = trackId
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.startTime = startTime
        self.volume = volume
        self.order = order
        self.subtitleText = subtitleText
    }

    // MARK: - Codable（向后兼容旧 schema：trackId / subtitleText 可能不存在）

    private enum CodingKeys: String, CodingKey {
        case id
        case mediaItemId
        case trackId
        case inPoint
        case outPoint
        case startTime
        case volume
        case order
        case subtitleText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        mediaItemId = try container.decode(String.self, forKey: .mediaItemId)
        trackId = try container.decodeIfPresent(String.self, forKey: .trackId) ?? ""
        inPoint = try container.decodeIfPresent(Double.self, forKey: .inPoint) ?? 0
        outPoint = try container.decodeIfPresent(Double.self, forKey: .outPoint) ?? 0
        startTime = try container.decodeIfPresent(Double.self, forKey: .startTime) ?? 0
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        subtitleText = try container.decodeIfPresent(String.self, forKey: .subtitleText)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mediaItemId, forKey: .mediaItemId)
        try container.encode(trackId, forKey: .trackId)
        try container.encode(inPoint, forKey: .inPoint)
        try container.encode(outPoint, forKey: .outPoint)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(volume, forKey: .volume)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(subtitleText, forKey: .subtitleText)
    }

    /// 片段有效时长（秒）
    public var duration: Double {
        max(0, outPoint - inPoint)
    }

    /// 在时间线上的结束时间（秒）
    public var endTime: Double {
        startTime + duration
    }
}

/// 时间线
public struct Timeline: Codable, Sendable, Equatable {
    /// 轨道列表
    public var tracks: [Track]

    public init(tracks: [Track] = []) {
        self.tracks = tracks
    }

    // MARK: - Codable（向后兼容旧 schema 的 clips 字段）

    private enum CodingKeys: String, CodingKey {
        case tracks
        case clips  // 旧 schema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 优先解码 tracks（新 schema）
        let decodedTracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        if !decodedTracks.isEmpty {
            self.tracks = decodedTracks
        } else {
            // 旧 schema：从 clips 构建 video track
            let oldClips = try container.decodeIfPresent([TimelineClip].self, forKey: .clips) ?? []
            if !oldClips.isEmpty {
                let videoTrack = Track(
                    name: "主视频",
                    type: .video,
                    clips: oldClips,
                    order: 0
                )
                self.tracks = [videoTrack]
            } else {
                self.tracks = []
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tracks, forKey: .tracks)
    }

    // MARK: - 向后兼容

    /// 所有视频轨道片段（向后兼容）
    public var clips: [TimelineClip] {
        get { videoTrack?.clips ?? [] }
        set {
            if let idx = tracks.firstIndex(where: { $0.type == .video }) {
                tracks[idx].clips = newValue
            }
        }
    }

    /// 获取或创建默认视频轨道
    public var videoTrack: Track? {
        tracks.first { $0.type == .video }
    }

    /// 获取字幕轨道
    public var subtitleTrack: Track? {
        tracks.first { $0.type == .subtitle }
    }

    /// 获取所有音频轨道
    public var audioTracks: [Track] {
        tracks.filter { $0.type == .audio }
    }

    // MARK: - 计算属性

    /// 时间线总时长（所有视频轨道的最大时长）
    public var totalDuration: Double {
        tracks.filter { $0.type == .video }
            .map { $0.totalDuration }
            .max() ?? 0
    }

    /// 所有视频轨道的排序片段（向后兼容）
    public var sortedClips: [TimelineClip] {
        clips.sorted { $0.order < $1.order }
    }

    /// 按 order 排序的轨道
    public var sortedTracks: [Track] {
        tracks.sorted { $0.order < $1.order }
    }

    // MARK: - 辅助方法

    /// 查找包含指定 clipId 的轨道
    public func track(containingClipId clipId: String) -> Track? {
        tracks.first { $0.clips.contains(where: { $0.id == clipId }) }
    }

    /// 查找指定 clip
    public func clip(byId clipId: String) -> TimelineClip? {
        for track in tracks {
            if let clip = track.clips.first(where: { $0.id == clipId }) {
                return clip
            }
        }
        return nil
    }
}
