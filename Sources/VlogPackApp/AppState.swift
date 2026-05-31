import Foundation
import SwiftUI
import VlogPackCore

/// 全局应用状态
@Observable
final class AppState {
    /// 当前打开的项目根目录
    var currentProjectRoot: URL?
    /// 当前项目模型
    var currentProject: VlogProject?
    /// 最近项目管理
    let recentProjects = RecentProjectStore()
    /// 项目服务
    let projectService = ProjectService()
    /// 设置服务
    let setupService = SetupService()

    /// 是否需要显示设置向导
    var needsSetup: Bool = false

    /// 是否已打开项目
    var hasOpenProject: Bool {
        currentProject != nil && currentProjectRoot != nil
    }

    /// 初始化：检查是否需要设置向导
    init() {
        self.needsSetup = setupService.needsSetup
    }

    /// 打开项目
    func openProject(at root: URL) throws {
        let project = try projectService.loadProject(from: root)
        currentProject = project
        currentProjectRoot = root
        recentProjects.recordOpen(
            projectName: project.projectName,
            projectRootPath: root.path
        )
    }

    /// 创建新项目
    func createProject(name: String, parentURL: URL) throws {
        let (root, project) = try projectService.createProject(
            projectName: name,
            parentURL: parentURL
        )
        currentProject = project
        currentProjectRoot = root
        recentProjects.recordOpen(
            projectName: project.projectName,
            projectRootPath: root.path
        )
    }

    /// 保存当前项目
    func saveCurrentProject() throws {
        guard let project = currentProject, let root = currentProjectRoot else {
            return
        }
        try projectService.saveProject(project, to: root)
    }

    /// 关闭项目
    func closeProject() {
        currentProject = nil
        currentProjectRoot = nil
    }

    /// 跳过设置
    func skipSetup() {
        setupService.markSetupComplete()
        needsSetup = false
    }

    /// 完成设置
    func completeSetup() {
        setupService.markSetupComplete()
        needsSetup = false
    }
}
