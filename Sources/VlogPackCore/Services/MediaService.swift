import Foundation

/// 素材服务错误
public enum MediaServiceError: Error, Sendable {
    case sourceFileNotFound(path: String)
    case copyFailed(source: String, destination: String)
    case unsupportedMediaType(path: String)
    case metadataReadFailed(path: String)
    case thumbnailGenerationFailed(path: String)
    case projectNotOpen
}

/// 素材计数器（用于命名）
private struct MediaCounters {
    var videoCount: Int = 0
    var imageCount: Int = 0
    var logoCount: Int = 0
}

/// 素材服务
public final class MediaService: @unchecked Sendable {
    private let thumbnailSize = CGSize(width: 320, height: 180)

    public init() {}

    // MARK: - 导入素材

    /// 导入文件到项目
    /// - Parameters:
    ///   - sourceURL: 原始文件 URL
    ///   - projectRoot: 项目根目录
    ///   - project: 当前项目模型（会被修改）
    /// - Returns: 新的 MediaItem
    @discardableResult
    public func importMedia(
        sourceURL: URL,
        projectRoot: URL,
        project: inout VlogProject
    ) throws -> MediaItem {
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceURL.path) else {
            throw MediaServiceError.sourceFileNotFound(path: sourceURL.path)
        }

        // 判断类型
        let mediaType = detectMediaType(url: sourceURL)

        // 计算命名序号
        let existingItems = project.mediaItems.filter { $0.type == mediaType }
        let nextIndex = existingItems.count + 1

        // 生成标准化文件名
        let ext = sourceURL.pathExtension.lowercased()
        let prefix = prefixForType(mediaType)
        let newFileName = FileNameGenerator.mediaFileName(
            prefix: prefix,
            index: nextIndex,
            pathExtension: ext
        )

        // 目标路径
        let subDir = mediaType == .video ? "media/original" : "media/imported"
        let destRelativePath = "\(subDir)/\(newFileName)"
        let destURL = projectRoot.appendingPathComponent(destRelativePath)

        // 确保目标目录存在
        let destDir = destURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: destDir.path) {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        // 复制文件
        do {
            try fm.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw MediaServiceError.copyFailed(
                source: sourceURL.path,
                destination: destURL.path
            )
        }

        // 读取元数据
        var duration: Double = 0
        var width = 0
        var height = 0
        var frameRate: Double = 0

        if mediaType == .video {
            do {
                let meta = try AVAssetMetadataReader.readMetadata(from: destURL)
                duration = meta.duration
                width = meta.width
                height = meta.height
                frameRate = meta.frameRate
            } catch {
                VlogPackLog.error("Failed to read metadata for \(newFileName): \(error)")
            }
        }

        // 构建 MediaItem
        let item = MediaItem(
            type: mediaType,
            originalFileName: sourceURL.lastPathComponent,
            projectRelativePath: destRelativePath,
            duration: duration,
            width: width,
            height: height,
            frameRate: frameRate
        )

        // 生成缩略图
        if mediaType == .video {
            generateThumbnailForItem(item, projectRoot: projectRoot)
        }

        // 更新项目
        project.mediaItems.append(item)
        return item
    }

    // MARK: - 批量导入

    /// 批量导入多个文件
    @discardableResult
    public func importMediaBatch(
        sourceURLs: [URL],
        projectRoot: URL,
        project: inout VlogProject
    ) throws -> [MediaItem] {
        var items: [MediaItem] = []
        for url in sourceURLs {
            let item = try importMedia(
                sourceURL: url,
                projectRoot: projectRoot,
                project: &project
            )
            items.append(item)
        }
        return items
    }

    // MARK: - 删除素材

    /// 从项目中删除素材
    public func removeMedia(
        itemId: String,
        projectRoot: URL,
        project: inout VlogProject
    ) throws {
        guard let index = project.mediaItems.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        let item = project.mediaItems[index]

        // 删除物理文件
        let fileURL = projectRoot.appendingPathComponent(item.projectRelativePath)
        try? FileManager.default.removeItem(at: fileURL)

        // 删除缩略图
        let thumbURL = projectRoot
            .appendingPathComponent("cache/thumbnails")
            .appendingPathComponent("\(item.id).jpg")
        try? FileManager.default.removeItem(at: thumbURL)

        // 从项目中移除
        project.mediaItems.remove(at: index)

        // 从时间线中移除关联的片段
        project.timeline.clips.removeAll { $0.mediaItemId == itemId }
    }

    // MARK: - 缩略图

    /// 生成/获取缩略图 URL
    public func thumbnailURL(for item: MediaItem, projectRoot: URL) -> URL? {
        let thumbURL = projectRoot
            .appendingPathComponent("cache/thumbnails")
            .appendingPathComponent("\(item.id).jpg")
        return FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL : nil
    }

    private func generateThumbnailForItem(_ item: MediaItem, projectRoot: URL) {
        let sourceURL = projectRoot.appendingPathComponent(item.projectRelativePath)
        let thumbDir = projectRoot.appendingPathComponent("cache/thumbnails")
        let thumbURL = thumbDir.appendingPathComponent("\(item.id).jpg")

        let time = item.duration > 1 ? min(1.0, item.duration * 0.1) : 0

        do {
            if let data = try AVAssetMetadataReader.generateThumbnail(
                from: sourceURL,
                at: time,
                maxSize: thumbnailSize
            ) {
                try data.write(to: thumbURL)
            }
        } catch {
            VlogPackLog.error("Thumbnail generation failed for \(item.id): \(error)")
        }
    }

    // MARK: - 内部方法

    private func detectMediaType(url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        let videoExtensions: Set<String> = [
            "mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mts", "m2ts"
        ]
        let logoExtensions: Set<String> = ["svg"]

        if videoExtensions.contains(ext) {
            return .video
        } else if logoExtensions.contains(ext) {
            return .logo
        }
        // PNG/JPG/HEIC 等默认为 image
        return .image
    }

    private func prefixForType(_ type: MediaType) -> String {
        switch type {
        case .video: return "clip"
        case .image: return "image"
        case .logo: return "logo"
        }
    }
}
