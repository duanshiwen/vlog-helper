import Foundation

/// 字幕片段
public struct SubtitleSegment: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    /// 开始时间（秒）
    public var start: Double
    /// 结束时间（秒）
    public var end: Double
    /// 字幕文本
    public var text: String

    public init(
        id: String = UUID().uuidString,
        start: Double = 0,
        end: Double = 0,
        text: String = ""
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    /// 时长（秒）
    public var duration: Double {
        max(0, end - start)
    }
}

/// 字幕位置
public enum SubtitlePosition: String, Codable, Sendable {
    case bottomCenter = "bottom-center"
    case topCenter = "top-center"
    case center
}

/// 字幕样式
public struct SubtitleStyle: Codable, Sendable, Equatable {
    public var fontFamily: String
    public var fontSize: Double
    public var textColor: String
    public var outlineColor: String
    public var outlineWidth: Double
    public var shadowColor: String
    public var shadowOpacity: Double
    public var shadowOffsetX: Double
    public var shadowOffsetY: Double
    public var position: SubtitlePosition
    public var marginBottom: Double
    /// 最大行宽比例（0-1）
    public var maxLineWidth: Double

    public init(
        fontFamily: String = "PingFang SC",
        fontSize: Double = 48,
        textColor: String = "#FFFFFF",
        outlineColor: String = "#000000",
        outlineWidth: Double = 3,
        shadowColor: String = "#000000",
        shadowOpacity: Double = 0.5,
        shadowOffsetX: Double = 2,
        shadowOffsetY: Double = 2,
        position: SubtitlePosition = .bottomCenter,
        marginBottom: Double = 90,
        maxLineWidth: Double = 0.82
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.textColor = textColor
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.position = position
        self.marginBottom = marginBottom
        self.maxLineWidth = maxLineWidth
    }
}

/// 字幕文档
public struct SubtitleDocument: Codable, Sendable, Equatable {
    public var segments: [SubtitleSegment]
    public var style: SubtitleStyle
    /// SRT 导出的项目相对路径
    public var srtPath: String?
    /// ASS 导出的项目相对路径
    public var assPath: String?

    public init(
        segments: [SubtitleSegment] = [],
        style: SubtitleStyle = SubtitleStyle(),
        srtPath: String? = nil,
        assPath: String? = nil
    ) {
        self.segments = segments
        self.style = style
        self.srtPath = srtPath
        self.assPath = assPath
    }
}
