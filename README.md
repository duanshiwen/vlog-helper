# VlogPack

**本地日更 Vlog 工作台** — macOS 原生 SwiftUI 视频编辑应用

VlogPack 是一款面向日更 Vlog 创作者的本地工作站，覆盖从素材导入到成片导出的完整制作流程。

## 功能

- 📁 **项目管理** — 每个 Vlog 一个独立项目文件夹，自包含所有素材
- 🎬 **素材导入** — 拖拽导入视频/图片，自动标准化命名和缩略图生成
- ✂️ **粗剪时间线** — 单轨 clip-based 时间线，拖动排序，in/out 裁剪
- 🗣️ **语音转字幕** — whisper.cpp 本地转写，生成字幕文档
- ✏️ **字幕编辑** — 编辑/合并/拆分字幕，搜索定位，SRT/ASS 导出
- 🎨 **字幕样式** — 字体/颜色/描边/阴影/位置完整编辑器
- 🖼️ **封面设计** — 视频抽帧候选，标题/Logo/样式编辑
- 📦 **一键导出** — MP4 视频 + 字幕烧录 + 封面导出
- 📋 **模板系统** — 内置字幕/封面模板，支持自定义模板

## 环境要求

- macOS 14.0+
- Xcode 26+ / Swift 6.2
- FFmpeg（可通过 Homebrew 安装：`brew install ffmpeg`）
- whisper.cpp（可选，用于语音转字幕）

## 快速开始

### 开发构建

```bash
# 克隆仓库
git clone <repo-url>
cd vlog-pack

# 构建并运行
./scripts/run-dev.sh

# 或手动构建
swift build
.build/debug/VlogPack.app/Contents/MacOS/VlogPack
```

### 构建 .app Bundle

```bash
# Debug 版本
./scripts/build-app.sh

# Release 版本
./scripts/build-app.sh --release

# 打开应用
open .build/debug/VlogPack.app
```

### 运行测试

```bash
swift test
```

## 项目结构

```
vlog-pack/
├── Package.swift
├── Sources/
│   ├── VlogPackCore/           # 核心库（模型、服务、适配器）
│   │   ├── Models/             # 数据模型
│   │   ├── Services/           # 业务逻辑服务
│   │   ├── Adapters/           # 外部工具适配器（FFmpeg, whisper.cpp）
│   │   └── Utils/              # 工具类
│   └── VlogPackApp/            # SwiftUI 应用
│       ├── Views/              # 所有视图
│       └── Resources/          # Info.plist, entitlements
├── Tests/                      # 单元测试
├── scripts/                    # 构建脚本
└── docs/                       # 设计文档
```

## 架构

- **VlogPackCore**：所有业务逻辑的纯 Swift 库，可独立测试
- **VlogPackApp**：SwiftUI 应用层，依赖 VlogPackCore
- **Adapters**：外部工具的 Process 调用封装
- **Services**：核心业务逻辑（项目管理、素材、时间线、字幕、封面、导出、模板）

## 首次启动

VlogPack 首次启动时会自动检测外部工具可用性：

1. **FFmpeg**（必需）— 视频处理引擎
2. **whisper.cpp**（可选）— 语音转文字引擎

如果 FFmpeg 未安装，应用会引导用户通过 Homebrew 安装。

## 项目文件格式

每个 Vlog 项目是一个自包含的文件夹：

```
2026-06-01-my-vlog/
├── project.vlogpack.json       # 项目主文件
├── media/
│   ├── original/               # 原始素材
│   └── imported/               # 导入素材
├── cache/
│   ├── thumbnails/             # 缩略图缓存
│   ├── audio/                  # 音频缓存
│   └── transcription/          # 转写缓存
├── subtitles/                  # 字幕文件
├── covers/                     # 封面文件
│   ├── candidates/             # 候选封面
│   └── final/                  # 最终封面
└── exports/                    # 导出文件
```

## 版本规划

- **v0.1**（当前）— MVP 完整流程：项目→素材→粗剪→字幕→封面→导出
- **v0.2** — UI 打磨、性能优化、多轨道
- **v1.0** — 正式发布

## 技术栈

- Swift 6.2 + macOS 14+
- SwiftUI（原生 macOS 应用）
- AVFoundation（视频元数据、播放）
- FFmpeg（视频处理，Process 调用）
- whisper.cpp（语音转文字，CLI 适配）

## License

Private — Connor Tech
