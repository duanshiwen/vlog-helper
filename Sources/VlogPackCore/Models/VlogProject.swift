import Foundation

/// VlogPack 项目主模型
public struct VlogProject: Codable, Sendable, Equatable {
    /// 项目文件 schema 版本
    public var schemaVersion: String
    public var projectId: String
    public var projectName: String
    public var createdAt: Date
    public var updatedAt: Date
    public var aspectRatio: AspectRatio
    public var resolution: Resolution
    public var mediaItems: [MediaItem]
    public var timeline: Timeline
    public var subtitles: SubtitleDocument?
    public var cover: CoverDesign?
    public var exportSettings: ExportSettings

    public init(
        schemaVersion: String = "0.2.0",
        projectId: String = UUID().uuidString,
        projectName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        aspectRatio: AspectRatio = .landscape16x9,
        resolution: Resolution = .hd1080,
        mediaItems: [MediaItem] = [],
        timeline: Timeline = Timeline(),
        subtitles: SubtitleDocument? = nil,
        cover: CoverDesign? = nil,
        exportSettings: ExportSettings = ExportSettings()
    ) {
        self.schemaVersion = schemaVersion
        self.projectId = projectId
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.mediaItems = mediaItems
        self.timeline = timeline
        self.subtitles = subtitles
        self.cover = cover
        self.exportSettings = exportSettings
    }

    // MARK: - Migration

    /// 将 v0.1.0 的扁平 clips 迁移到 v0.2.0 的多轨结构
    public mutating func migrateToMultiTrackIfNeeded() {
        if schemaVersion == "0.1.0" || timeline.tracks.isEmpty && !timeline.clips.isEmpty {
            let videoTrack = Track(
                name: "主视频",
                type: .video,
                clips: timeline.clips,
                order: 0
            )
            timeline = Timeline(tracks: [videoTrack])
            schemaVersion = "0.2.0"
        } else if timeline.tracks.isEmpty {
            // 全新项目：创建默认视频轨道
            let videoTrack = Track(name: "主视频", type: .video, order: 0)
            timeline = Timeline(tracks: [videoTrack])
        }
    }
}
