import Foundation

/// 封面服务
public final class CoverService: @unchecked Sendable {
    private let ffmpeg: FFmpegAdapter

    public init(ffmpeg: FFmpegAdapter = FFmpegAdapter()) {
        self.ffmpeg = ffmpeg
    }

    // MARK: - 视频抽帧候选

    /// 从时间线视频中抽取候选帧
    public func generateCandidates(
        project: VlogProject,
        projectRoot: URL,
        percentages: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
    ) throws -> [String] {
        let timelineService = TimelineService()
        let totalDuration = timelineService.totalDuration(project: project)
        guard totalDuration > 0 else { return [] }

        let candidatesDir = projectRoot.appendingPathComponent("covers/candidates")
        try FileManager.default.createDirectory(
            at: candidatesDir,
            withIntermediateDirectories: true
        )

        // 使用第一个有素材的 clip 来抽帧
        guard let firstClip = project.timeline.sortedClips.first,
              let mediaItem = timelineService.mediaItem(forClip: firstClip, project: project) else {
            return []
        }

        let videoPath = projectRoot.appendingPathComponent(mediaItem.projectRelativePath)
        var candidatePaths: [String] = []

        for (index, pct) in percentages.enumerated() {
            let time = totalDuration * pct
            let outputName = "candidate_\(String(format: "%03d", index + 1)).jpg"
            let outputPath = candidatesDir.appendingPathComponent(outputName)

            let result = try ffmpeg.extractFrame(
                videoPath: videoPath.path,
                time: time,
                outputPath: outputPath.path
            )

            if result.success {
                let relativePath = "covers/candidates/\(outputName)"
                candidatePaths.append(relativePath)
            }
        }

        return candidatePaths
    }

    // MARK: - 创建/更新封面设计

    /// 初始化封面设计
    public func createCoverDesign(
        sourceType: CoverSourceType,
        sourcePath: String,
        title: String = ""
    ) -> CoverDesign {
        CoverDesign(
            sourceType: sourceType,
            sourcePath: sourcePath,
            title: title
        )
    }

    /// 更新封面标题
    public func updateTitle(_ title: String, project: inout VlogProject) {
        if project.cover == nil {
            project.cover = CoverDesign()
        }
        project.cover?.title = title
    }

    /// 更新封面背景图
    public func updateBackground(sourcePath: String, project: inout VlogProject) {
        if project.cover == nil {
            project.cover = CoverDesign()
        }
        project.cover?.sourcePath = sourcePath
    }

    /// 更新封面文字样式
    public func updateTextStyle(_ style: CoverTextStyle, project: inout VlogProject) {
        project.cover?.textStyle = style
    }

    /// 设置 Logo
    public func setLogo(path: String?, frame: RectCodable? = nil, project: inout VlogProject) {
        project.cover?.logoPath = path
        project.cover?.logoFrame = frame
    }

    // MARK: - 导出封面

    /// 导出封面图
    /// 注意：v0.1 使用 CoreGraphics 渲染，此方法保存封面设计到 JSON，
    /// 实际图片渲染在 SwiftUI 层完成
    public func exportCover(
        project: VlogProject,
        projectRoot: URL
    ) throws -> String? {
        guard let cover = project.cover else { return nil }

        // 保存封面设计 JSON
        let coverURL = projectRoot.appendingPathComponent("covers/cover-design.json")
        try JSONStore.write(cover, to: coverURL)

        // 复制到 exports（如果有输出图片）
        if let outputPath = cover.outputPath {
            let source = projectRoot.appendingPathComponent(outputPath)
            let dest = projectRoot.appendingPathComponent("exports/cover.jpg")
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: source, to: dest)
            }
            return "exports/cover.jpg"
        }

        return nil
    }

    // MARK: - 将候选帧设为封面背景

    /// 从候选帧中选择一个作为封面背景
    public func selectCandidate(
        candidatePath: String,
        project: inout VlogProject
    ) {
        if project.cover == nil {
            project.cover = CoverDesign(
                sourceType: .videoFrame,
                sourcePath: candidatePath
            )
        } else {
            project.cover?.sourceType = .videoFrame
            project.cover?.sourcePath = candidatePath
        }
    }
}
