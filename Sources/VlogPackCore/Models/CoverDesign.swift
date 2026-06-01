import Foundation

/// 封面来源类型
public enum CoverSourceType: String, Codable, Sendable {
    case videoFrame = "video-frame"
    case manual
}

/// 背景变换
public struct BackgroundTransform: Codable, Sendable, Equatable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(scale: Double = 1.0, offsetX: Double = 0, offsetY: Double = 0) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

/// 矩形区域（Codable 版）
public struct RectCodable: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 封面文本样式
public struct CoverTextStyle: Codable, Sendable, Equatable {
    public var fontFamily: String
    public var fontSize: Double
    public var textColor: String
    public var outlineColor: String
    public var outlineWidth: Double
    public var shadowColor: String
    public var shadowOpacity: Double
    public var shadowOffsetX: Double
    public var shadowOffsetY: Double

    public init(
        fontFamily: String = "PingFang SC",
        fontSize: Double = 64,
        textColor: String = "#FFFFFF",
        outlineColor: String = "#000000",
        outlineWidth: Double = 4,
        shadowColor: String = "#000000",
        shadowOpacity: Double = 0.6,
        shadowOffsetX: Double = 3,
        shadowOffsetY: Double = 3
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
    }
}

/// 封面设计
public struct CoverDesign: Codable, Sendable, Equatable {
    public var sourceType: CoverSourceType
    /// 背景图项目相对路径
    public var sourcePath: String
    public var title: String
    public var templateId: String?
    public var textStyle: CoverTextStyle
    /// Logo 项目相对路径
    public var logoPath: String?
    public var logoFrame: RectCodable?
    public var backgroundTransform: BackgroundTransform
    /// 封面导出项目相对路径
    public var outputPath: String?

    public init(
        sourceType: CoverSourceType = .manual,
        sourcePath: String = "",
        title: String = "",
        templateId: String? = nil,
        textStyle: CoverTextStyle = CoverTextStyle(),
        logoPath: String? = nil,
        logoFrame: RectCodable? = nil,
        backgroundTransform: BackgroundTransform = BackgroundTransform(),
        outputPath: String? = nil
    ) {
        self.sourceType = sourceType
        self.sourcePath = sourcePath
        self.title = title
        self.templateId = templateId
        self.textStyle = textStyle
        self.logoPath = logoPath
        self.logoFrame = logoFrame
        self.backgroundTransform = backgroundTransform
        self.outputPath = outputPath
    }
}
