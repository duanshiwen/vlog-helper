import Foundation

/// 项目服务错误
public enum ProjectServiceError: Error, Sendable, Equatable {
    case directoryCreationFailed(path: String)
    case projectFileWriteFailed(path: String)
    case projectFileReadFailed(path: String)
    case projectNotFound(path: String)
    case invalidProjectFile(reason: String)
}

/// 项目文件夹标准子目录
public enum ProjectFolderLayout {
    public static let subdirectories: [String] = [
        "media/original",
        "media/imported",
        "cache/thumbnails",
        "cache/audio",
        "cache/transcription",
        "cache/temp",
        "cache/waveforms",
        "subtitles",
        "covers/candidates",
        "covers/final",
        "exports",
        "logs",
    ]

    public static let projectFileName = "project.vlogpack.json"
}

/// 项目服务：管理项目的创建、打开、保存
public final class ProjectService: @unchecked Sendable {
    public init() {}

    // MARK: - 创建项目

    /// 在指定父目录下创建新项目
    /// - Parameters:
    ///   - projectName: 用户输入的项目名
    ///   - parentURL: 项目保存目录（父目录）
    ///   - date: 创建日期（默认当前）
    /// - Returns: (项目根目录 URL, 项目模型)
    public func createProject(
        projectName: String,
        parentURL: URL,
        date: Date = Date()
    ) throws -> (projectRoot: URL, project: VlogProject) {
        let folderName = FileNameGenerator.projectFolderName(
            projectName: projectName,
            date: date
        )
        let projectRoot = parentURL.appendingPathComponent(folderName)

        // 创建项目根目录
        let fm = FileManager.default
        do {
            try fm.createDirectory(
                at: projectRoot,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ProjectServiceError.directoryCreationFailed(
                path: projectRoot.path
            )
        }

        // 创建标准子目录
        for sub in ProjectFolderLayout.subdirectories {
            let subURL = projectRoot.appendingPathComponent(sub)
            do {
                try fm.createDirectory(
                    at: subURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw ProjectServiceError.directoryCreationFailed(
                    path: subURL.path
                )
            }
        }

        // 构建项目模型
        let project = VlogProject(projectName: projectName, createdAt: date)

        // 写入项目文件
        let projectFileURL = projectRoot.appendingPathComponent(
            ProjectFolderLayout.projectFileName
        )
        do {
            try JSONStore.write(project, to: projectFileURL)
        } catch {
            throw ProjectServiceError.projectFileWriteFailed(
                path: projectFileURL.path
            )
        }

        return (projectRoot, project)
    }

    // MARK: - 打开项目

    /// 从项目根目录加载项目
    public func loadProject(from projectRoot: URL) throws -> VlogProject {
        let projectFileURL = projectRoot.appendingPathComponent(
            ProjectFolderLayout.projectFileName
        )

        let fm = FileManager.default
        guard fm.fileExists(atPath: projectFileURL.path) else {
            throw ProjectServiceError.projectNotFound(
                path: projectFileURL.path
            )
        }

        do {
            var project: VlogProject = try JSONStore.read(from: projectFileURL)
            // 自动迁移到多轨结构
            project.migrateToMultiTrackIfNeeded()
            return project
        } catch {
            throw ProjectServiceError.projectFileReadFailed(
                path: projectFileURL.path
            )
        }
    }

    // MARK: - 保存项目

    /// 保存项目到其根目录
    public func saveProject(_ project: VlogProject, to projectRoot: URL) throws {
        var updated = project
        updated.updatedAt = Date()

        let projectFileURL = projectRoot.appendingPathComponent(
            ProjectFolderLayout.projectFileName
        )
        do {
            try JSONStore.write(updated, to: projectFileURL)
        } catch {
            throw ProjectServiceError.projectFileWriteFailed(
                path: projectFileURL.path
            )
        }
    }

    // MARK: - 完整性校验

    /// 检查项目文件夹完整性，返回缺失的子目录
    public func checkIntegrity(projectRoot: URL) -> [String] {
        let fm = FileManager.default
        var missing: [String] = []

        for sub in ProjectFolderLayout.subdirectories {
            let subURL = projectRoot.appendingPathComponent(sub)
            if !fm.fileExists(atPath: subURL.path) {
                missing.append(sub)
            }
        }

        return missing
    }

    /// 修复缺失的子目录
    public func repairProject(projectRoot: URL) throws {
        let missing = checkIntegrity(projectRoot: projectRoot)
        let fm = FileManager.default

        for sub in missing {
            let subURL = projectRoot.appendingPathComponent(sub)
            try fm.createDirectory(
                at: subURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
