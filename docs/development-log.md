# VlogPack 开发日志

## 2026-06-01 — Milestone 0 + Milestone 1 完成

**范围**：仓库初始化 + Swift 工程骨架 + 项目系统 MVP

**完成内容**：
- Git 仓库初始化
- SwiftUI macOS App + VlogPackCore 双 target 架构
- 核心数据模型：VlogProject, MediaItem, Timeline, TimelineClip, SubtitleDocument, SubtitleStyle, CoverDesign, ExportSettings, Resolution, AspectRatio
- ProjectService：创建项目、加载项目、保存项目、完整性校验、修复
- RecentProjectStore：最近项目列表管理
- SwiftUI 界面：LaunchView（启动页+新建项目+最近项目）、NewProjectSheet、WorkspaceView（占位）
- JSONStore、FileNameGenerator、Logger 工具类
- 19 个单元测试全部通过

**测试覆盖**：
- ProjectServiceTests: 6 tests（创建、加载、保存、完整性、修复、错误处理）
- MediaNamingTests: 6 tests（文件夹名、素材文件名）
- ModelRoundTripTests: 7 tests（JSON round-trip、时间计算、排序）

**技术栈**：
- Swift 6.2 / macOS 14+
- SwiftUI + @Observable
- Swift Package Manager
- 测试框架：Testing (Swift 6)

**下一步**：Milestone 2 — 素材导入
