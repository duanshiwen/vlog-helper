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

---

## 2026-06-01 — Milestones 2–9 全部完成

**范围**：素材导入 → 时间线 → 导出 → 转写 → 字幕编辑 → 字幕样式 → 封面 → 模板

**完成内容**：
- MediaService：拖拽导入、复制到项目、标准化命名、AVFoundation 元数据读取、缩略图生成
- TimelineService：添加/删除/移动片段、in/out 裁剪、总时长计算、FFmpeg 导出计划生成
- FFmpegAdapter：FFmpeg/FFprobe Process 调用、音频提取、字幕烧录、视频抽帧、进度回调
- WhisperAdapter：whisper.cpp CLI 适配、JSON 输出解析
- TranscriptionService：时间线 → 音频提取 → whisper 转写 → 字幕格式转换
- SubtitleService：编辑/合并/拆分字幕、搜索、SRT/ASS 导出（含完整 ASS 样式生成）
- CoverService：视频抽帧候选、封面设计管理、封面导出
- TemplateService：内置字幕/封面模板、自定义模板保存/加载、模板应用
- ExportService：无字幕导出、字幕烧录导出、字幕文件导出、导出日志
- UI 完整实现：MediaLibraryView、TimelineView、PreviewPlayerView、InspectorPanelView、SubtitleEditorView、SubtitleStyleEditor、CoverEditorView、ExportView、ProjectInfoView
- 测试：从 19 个扩展到 37 个（新增 TimelineService 6 + SubtitleService 7 + TemplateService 5）

**技术挑战与解决**：
- Swift 6 并发严格模式：所有 Task.detached 中的 actor-isolated 属性访问需提前捕获
- AVKit VideoPlayer 在 swift build CLI 中不可用：改用 NSViewRepresentable + AVPlayerView
- AVFoundation deprecated API：已标注，后续迁移至 async load* API
- FFmpegKit 已退休：采用 Process 直接调用本地 FFmpeg 二进制

**下一步**：集成测试、macOS App 打包（codesign + notarization）、性能优化
