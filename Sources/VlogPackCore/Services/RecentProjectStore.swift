import Foundation

/// 最近项目条目
public struct RecentProjectEntry: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var projectName: String
    public var projectRootPath: String
    public var lastOpenedAt: Date

    public init(
        id: String = UUID().uuidString,
        projectName: String,
        projectRootPath: String,
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.projectName = projectName
        self.projectRootPath = projectRootPath
        self.lastOpenedAt = lastOpenedAt
    }

    /// 是否仍可打开（目录存在）
    public var isOpenable: Bool {
        FileManager.default.fileExists(atPath: projectRootPath)
    }
}

/// 最近项目列表管理
public final class RecentProjectStore: @unchecked Sendable {
    private let storeURL: URL
    private var entries: [RecentProjectEntry] = []

    public init(storeURL: URL? = nil) {
        let defaultURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".vlogpack")
            .appendingPathComponent("recent-projects.json")
        self.storeURL = storeURL ?? defaultURL
        load()
    }

    /// 所有最近项目（按时间倒序）
    public var all: [RecentProjectEntry] {
        entries.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    /// 添加或更新最近项目
    public func recordOpen(projectName: String, projectRootPath: String) {
        // 移除旧记录
        entries.removeAll { $0.projectRootPath == projectRootPath }
        // 插入新记录
        let entry = RecentProjectEntry(
            projectName: projectName,
            projectRootPath: projectRootPath
        )
        entries.insert(entry, at: 0)
        // 保留最近 50 条
        if entries.count > 50 {
            entries = Array(entries.prefix(50))
        }
        save()
    }

    /// 移除记录
    public func remove(projectRootPath: String) {
        entries.removeAll { $0.projectRootPath == projectRootPath }
        save()
    }

    // MARK: - 持久化

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            entries = []
            return
        }
        do {
            entries = try JSONStore.read(from: storeURL)
        } catch {
            VlogPackLog.error("Failed to load recent projects: \(error)")
            entries = []
        }
    }

    private func save() {
        do {
            let fm = FileManager.default
            let dir = storeURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try JSONStore.write(entries, to: storeURL)
        } catch {
            VlogPackLog.error("Failed to save recent projects: \(error)")
        }
    }
}
