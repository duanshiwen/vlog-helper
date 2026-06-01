import Foundation

/// 导出设置
public struct ExportSettings: Codable, Sendable, Equatable {
    public var resolution: Resolution
    public var format: String
    public var videoCodec: String
    public var audioCodec: String
    public var burnSubtitles: Bool
    public var outputPath: String

    public init(
        resolution: Resolution = .hd1080,
        format: String = "mp4",
        videoCodec: String = "h264",
        audioCodec: String = "aac",
        burnSubtitles: Bool = false,
        outputPath: String = "exports/final.mp4"
    ) {
        self.resolution = resolution
        self.format = format
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.burnSubtitles = burnSubtitles
        self.outputPath = outputPath
    }
}
