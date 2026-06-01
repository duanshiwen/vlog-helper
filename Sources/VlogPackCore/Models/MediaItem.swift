import Foundation

/// 素材类型
public enum MediaType: String, Codable, Sendable {
    case video
    case image
    case logo
}

/// 素材条目
public struct MediaItem: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var type: MediaType
    public var originalFileName: String
    /// 项目根目录的相对路径，如 "media/original/clip_001.mov"
    public var projectRelativePath: String
    public var duration: Double
    public var width: Int
    public var height: Int
    public var frameRate: Double
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        type: MediaType,
        originalFileName: String,
        projectRelativePath: String,
        duration: Double = 0,
        width: Int = 0,
        height: Int = 0,
        frameRate: Double = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.originalFileName = originalFileName
        self.projectRelativePath = projectRelativePath
        self.duration = duration
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.createdAt = createdAt
    }
}
