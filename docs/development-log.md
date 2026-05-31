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

**下一步**：macOS App 打包、性能优化、UI 打磨

---

## 2026-06-01 — macOS App 打包基础设施

**完成内容**：
- `Info.plist`：完整的 macOS 应用配置，包含权限描述、文件关联
- `VlogPack.entitlements`：沙盒/网络/文件权限配置
- `scripts/build-app.sh`：一键构建 .app Bundle，自动内置 FFmpeg/FFprobe/whisper.cpp
- `scripts/package-dmg.sh`：创建 DMG 安装包
- `WhisperModelManager`：模型下载/存储/管理，支持 5 种规格（tiny → large-v3）
- `SettingsView`：外部工具状态检查 + Whisper 模型管理 UI
- FFmpegAdapter/WhisperAdapter：Bundle-aware 路径解析（Bundle > MacOS 目录 > 环境变量 > Homebrew）

**打包验证**：
- ✅ .app Bundle 构建成功，FFmpeg/FFprobe/whisper.cpp 全部内置
- ✅ Ad-hoc 签名通过
- ✅ 37 个测试全部通过
- ✅ Bundle 结构：VlogPack.app/Contents/{MacOS,Resources,Info.plist,_CodeSignature}

**下一步**：UI 打磨、拖拽排序时间线、字幕预览、性能优化

---

## 2026-06-01 — 首次启动引导 + 设置系统

**完成内容**：
- `ToolLocator`：FFmpeg/whisper.cpp 多路径解析器（App Bundle → Homebrew → PATH → 环境变量 → fallback）
- `SetupService`：首次启动状态管理，持久化到 ~/.vlogpack/setup-state.json
- `SetupWizardView`：首次启动设置向导（工具卡片状态检测 + Homebrew 安装引导 + 跳过选项）
- `SettingsView`：应用设置页（通用/工具/模板三 Tab）
- `scripts/build-app.sh`：.app Bundle 构建脚本，自动内置 FFmpeg/FFprobe
- `scripts/run-dev.sh`：开发快速构建+运行一键脚本
- 更新 AppState/ContentView 集成设置向导流程
- 更新 Package.swift 正确排除 Resources 目录
- 更新 README 完整项目文档

**验证**：
- swift build ✅
- swift test ✅ (37 tests, 6 suites)
- ./scripts/build-app.sh ✅ 生成可运行 .app
- App 可正常启动运行

**下一步**：集成测试（真实视频全流程）、UI 打磨、性能优化
