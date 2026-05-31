# VlogPack 架构文档

## 总体架构

```text
┌─────────────────────────────────────────────┐
│            SwiftUI App Shell                │
│  LaunchView / NewProjectView / WorkspaceView │
├─────────────────────────────────────────────┤
│              VlogPackCore                   │
│  ┌────────────┐ ┌────────────┐              │
│  │ Project    │ │ Media      │              │
│  │ Service    │ │ Service    │              │
│  └────────────┘ └────────────┘              │
│  ┌────────────┐ ┌────────────┐              │
│  │ Timeline   │ │ Subtitle   │              │
│  │ Service    │ │ Service    │              │
│  └────────────┘ └────────────┘              │
│  ┌────────────┐ ┌────────────┐              │
│  │ Cover      │ │ Export     │              │
│  │ Service    │ │ Service    │              │
│  └────────────┘ └────────────┘              │
│  ┌────────────┐ ┌────────────┐              │
│  │ Transcrip- │ │ Template   │              │
│  │ tion Svc   │ │ Service    │              │
│  └────────────┘ └────────────┘              │
├─────────────────────────────────────────────┤
│               Adapters                      │
│  FFmpegAdapter │ WhisperAdapter │ AVFoundation │
├─────────────────────────────────────────────┤
│            Project Folder                   │
│  media/ │ cache/ │ subtitles/ │ covers/ │ exports/ │ logs/ │
└─────────────────────────────────────────────┘
```

## 核心原则

1. **Service 层与 UI 层解耦**：所有业务逻辑在 `VlogPackCore` 中，SwiftUI 视图只负责展示与交互
2. **数据模型 Codable**：所有模型必须可 JSON 序列化，支持项目文件 round-trip
3. **Adapters 封装外部依赖**：FFmpeg、whisper.cpp、AVFoundation 通过 Adapter 隔离，便于测试与替换
4. **Project 相对路径**：所有内部路径存储项目相对路径，根路径运行时推导

## 模块职责

### ProjectService
- 创建项目、生成目录结构
- 保存/加载 `project.vlogpack.json`
- 最近项目列表
- 项目完整性校验

### MediaService
- 导入素材（视频/图片/Logo）
- 复制到项目目录、标准化命名
- 读取 AVFoundation 元数据
- 生成缩略图

### TimelineService
- 管理片段顺序与 in/out 点
- 计算总时长
- 生成 FFmpeg 导出参数
- 为转写生成临时音频

### TranscriptionService
- 准备音频
- 调用 whisper.cpp
- 保存原始转写结果
- 转换为内部字幕格式

### SubtitleService
- 字幕片段管理（编辑、合并、拆分）
- 时间轴调整
- 样式管理
- 导出 SRT / ASS

### CoverService
- 视频抽帧
- 候选封面管理
- 封面渲染（标题、Logo、渐变遮罩）
- 导出封面图

### ExportService
- 无字幕视频导出
- 字幕烧录导出
- 所有最终文件归档到 `exports/`

### TemplateService
- 内置模板加载
- 自定义模板保存
- 模板应用

## 项目文件夹结构

```text
YYYY-MM-DD-slug/
  project.vlogpack.json
  media/
    original/
    imported/
  cache/
    thumbnails/
    audio/
    transcription/
    temp/
    waveforms/
  subtitles/
  covers/
    candidates/
    final/
  exports/
  logs/
```

## 技术约束

- macOS 原生 SwiftUI，不使用 Electron / Tauri
- 单视频轨、无 BGM、无转场（v0.1）
- 仅 16:9 横屏（v0.1）
- 所有处理本地完成
- FFmpeg 通过 Process 调用本地二进制
- whisper.cpp 通过 Process 或 Swift binding 集成
