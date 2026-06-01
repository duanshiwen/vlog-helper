import Foundation
import Testing
@testable import VlogPackCore

// MARK: - ProjectService Tests

@Suite("ProjectService")
struct ProjectServiceTests {

    // 临时目录 helper
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vlogpack-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("创建项目：生成正确的目录结构和项目文件")
    func testCreateProject() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, project) = try service.createProject(
            projectName: "杭州日更 Vlog",
            parentURL: parent,
            date: makeFixedDate()
        )

        // 验证文件夹名包含日期
        #expect(projectRoot.lastPathComponent.hasPrefix("2026-06-01-"))

        // 验证项目文件存在
        let projectFile = projectRoot.appendingPathComponent(
            ProjectFolderLayout.projectFileName
        )
        #expect(FileManager.default.fileExists(atPath: projectFile.path))

        // 验证项目模型
        #expect(project.schemaVersion == "0.2.0")
        #expect(project.projectName == "杭州日更 Vlog")
        #expect(project.aspectRatio == .landscape16x9)
        #expect(project.resolution == .hd1080)

        // 验证标准子目录
        for sub in ProjectFolderLayout.subdirectories {
            let subURL = projectRoot.appendingPathComponent(sub)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: subURL.path,
                isDirectory: &isDir
            )
            #expect(exists, "子目录不存在: \(sub)")
            #expect(isDir.boolValue, "不是目录: \(sub)")
        }
    }

    @Test("加载项目：可以 round-trip 保存并读取")
    func testLoadProject() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, original) = try service.createProject(
            projectName: "测试项目",
            parentURL: parent
        )

        let loaded = try service.loadProject(from: projectRoot)
        #expect(loaded.projectId == original.projectId)
        #expect(loaded.projectName == original.projectName)
        #expect(loaded.schemaVersion == original.schemaVersion)
    }

    @Test("保存项目：updatedAt 字段被写入")
    func testSaveWritesUpdatedAt() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, original) = try service.createProject(
            projectName: "时间戳测试",
            parentURL: parent
        )

        // 构造一个明确更早的时间作为 updatedAt
        var modified = original
        modified.updatedAt = Date(timeIntervalSince1970: 0)

        // 保存会将 updatedAt 重置为 Date()
        try service.saveProject(modified, to: projectRoot)
        let loaded: VlogProject = try JSONStore.read(
            from: projectRoot.appendingPathComponent(ProjectFolderLayout.projectFileName)
        )

        // updatedAt 应远大于 epoch，说明被 saveProject 重写了
        #expect(loaded.updatedAt > Date(timeIntervalSince1970: 1_000_000_000))
    }

    @Test("完整性检查：正常项目返回空缺失列表")
    func testIntegrityCheck() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, _) = try service.createProject(
            projectName: "完整性测试",
            parentURL: parent
        )

        let missing = service.checkIntegrity(projectRoot: projectRoot)
        #expect(missing.isEmpty)
    }

    @Test("完整性检查：删除子目录后能检测到缺失")
    func testIntegrityCheckFindsMissing() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, _) = try service.createProject(
            projectName: "缺失测试",
            parentURL: parent
        )

        // 删除一个子目录
        let toDelete = projectRoot.appendingPathComponent("cache/thumbnails")
        try FileManager.default.removeItem(at: toDelete)

        let missing = service.checkIntegrity(projectRoot: projectRoot)
        #expect(missing.contains("cache/thumbnails"))
    }

    @Test("修复项目：可以恢复缺失的子目录")
    func testRepairProject() throws {
        let parent = try makeTempDir()
        defer { cleanup(parent) }

        let service = ProjectService()
        let (projectRoot, _) = try service.createProject(
            projectName: "修复测试",
            parentURL: parent
        )

        let toDelete = projectRoot.appendingPathComponent("exports")
        try FileManager.default.removeItem(at: toDelete)

        // 修复
        try service.repairProject(projectRoot: projectRoot)

        let missing = service.checkIntegrity(projectRoot: projectRoot)
        #expect(missing.isEmpty)
    }

    @Test("加载不存在的项目：抛出错误")
    func testLoadNonexistentProject() throws {
        let service = ProjectService()
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-vlogpack-project-\(UUID())")

        #expect(throws: ProjectServiceError.self) {
            try service.loadProject(from: fakeURL)
        }
    }
}

// MARK: - Fixed Date Helper

/// 固定日期，使测试结果可预测
private func makeFixedDate() -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    components.hour = 10
    components.minute = 0
    components.second = 0
    return Calendar.current.date(from: components) ?? Date()
}
