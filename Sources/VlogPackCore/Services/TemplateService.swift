import Foundation

/// 模板类型
public enum TemplateType: String, Codable, Sendable {
    case subtitle
    case cover
}

/// 模板条目
public struct TemplateEntry: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var type: TemplateType
    public var data: Data

    public init(id: String = UUID().uuidString, name: String, type: TemplateType, data: Data) {
        self.id = id
        self.name = name
        self.type = type
        self.data = data
    }
}

/// 模板服务
public final class TemplateService: @unchecked Sendable {
    private let templatesDir: URL

    public init(templatesDir: URL? = nil) {
        let defaultDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".vlogpack")
            .appendingPathComponent("templates")
        self.templatesDir = templatesDir ?? defaultDir
    }

    // MARK: - 内置模板

    /// 获取内置字幕模板
    public var builtinSubtitleTemplates: [String: SubtitleStyle] {
        [
            "daily-clean": SubtitleStyle(
                fontFamily: "PingFang SC",
                fontSize: 48,
                textColor: "#FFFFFF",
                outlineColor: "#000000",
                outlineWidth: 3,
                shadowColor: "#000000",
                shadowOpacity: 0.5,
                shadowOffsetX: 2,
                shadowOffsetY: 2,
                position: .bottomCenter,
                marginBottom: 90,
                maxLineWidth: 0.82
            ),
            "bold-vlog": SubtitleStyle(
                fontFamily: "PingFang SC",
                fontSize: 56,
                textColor: "#FFFFFF",
                outlineColor: "#FF3366",
                outlineWidth: 4,
                shadowColor: "#000000",
                shadowOpacity: 0.7,
                shadowOffsetX: 3,
                shadowOffsetY: 3,
                position: .bottomCenter,
                marginBottom: 80,
                maxLineWidth: 0.75
            ),
            "documentary": SubtitleStyle(
                fontFamily: "Songti SC",
                fontSize: 44,
                textColor: "#FFFFF0",
                outlineColor: "#333333",
                outlineWidth: 2,
                shadowColor: "#000000",
                shadowOpacity: 0.4,
                shadowOffsetX: 1,
                shadowOffsetY: 1,
                position: .bottomCenter,
                marginBottom: 100,
                maxLineWidth: 0.85
            ),
        ]
    }

    /// 获取内置封面模板
    public var builtinCoverTemplates: [String: CoverTextStyle] {
        [
            "daily-travel": CoverTextStyle(
                fontFamily: "PingFang SC",
                fontSize: 64,
                textColor: "#FFFFFF",
                outlineColor: "#000000",
                outlineWidth: 4,
                shadowColor: "#000000",
                shadowOpacity: 0.6,
                shadowOffsetX: 3,
                shadowOffsetY: 3
            ),
            "city-walk": CoverTextStyle(
                fontFamily: "PingFang SC",
                fontSize: 56,
                textColor: "#FFFFFF",
                outlineColor: "#1A1A2E",
                outlineWidth: 5,
                shadowColor: "#16213E",
                shadowOpacity: 0.8,
                shadowOffsetX: 4,
                shadowOffsetY: 4
            ),
            "documentary-clean": CoverTextStyle(
                fontFamily: "Songti SC",
                fontSize: 48,
                textColor: "#F5F5DC",
                outlineColor: "#2C2C2C",
                outlineWidth: 3,
                shadowColor: "#000000",
                shadowOpacity: 0.5,
                shadowOffsetX: 2,
                shadowOffsetY: 2
            ),
        ]
    }

    // MARK: - 自定义模板

    /// 保存当前字幕样式为自定义模板
    public func saveSubtitleTemplate(name: String, style: SubtitleStyle) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(style)

        try ensureTemplatesDir()
        let url = templatesDir.appendingPathComponent("subtitle-\(name).json")
        try data.write(to: url, options: .atomic)
    }

    /// 保存当前封面样式为自定义模板
    public func saveCoverTemplate(name: String, style: CoverTextStyle) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(style)

        try ensureTemplatesDir()
        let url = templatesDir.appendingPathComponent("cover-\(name).json")
        try data.write(to: url, options: .atomic)
    }

    /// 加载自定义字幕模板
    public func loadSubtitleTemplate(name: String) throws -> SubtitleStyle {
        let url = templatesDir.appendingPathComponent("subtitle-\(name).json")
        return try JSONStore.read(from: url)
    }

    /// 加载自定义封面模板
    public func loadCoverTemplate(name: String) throws -> CoverTextStyle {
        let url = templatesDir.appendingPathComponent("cover-\(name).json")
        return try JSONStore.read(from: url)
    }

    /// 列出所有自定义模板名
    public func listCustomTemplates() throws -> [String] {
        try ensureTemplatesDir()
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(atPath: templatesDir.path)
        return files.filter { $0.hasSuffix(".json") }.map {
            $0.replacingOccurrences(of: ".json", with: "")
        }
    }

    /// 应用字幕模板到项目
    public func applySubtitleTemplate(_ style: SubtitleStyle, project: inout VlogProject) {
        if project.subtitles == nil {
            project.subtitles = SubtitleDocument()
        }
        project.subtitles?.style = style
    }

    /// 应用封面模板到项目
    public func applyCoverTemplate(_ style: CoverTextStyle, project: inout VlogProject) {
        if project.cover == nil {
            project.cover = CoverDesign()
        }
        project.cover?.textStyle = style
    }

    // MARK: - 内部

    private func ensureTemplatesDir() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: templatesDir.path) {
            try fm.createDirectory(at: templatesDir, withIntermediateDirectories: true)
        }
    }
}
