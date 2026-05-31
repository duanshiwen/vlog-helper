# VlogPack

macOS 本地日更 Vlog 工作台。

> 让每天的视频发布流程变得稳定、快速、可复用、可追溯。

## 产品定位

VlogPack 是一个原生 SwiftUI macOS 应用，以"一个 Vlog = 一个项目文件夹"为单位，帮助创作者完成：

- 素材归档与管理
- 轻量粗剪（单视频轨 + 排序/裁剪）
- 中文字幕本地转写与校对
- 字幕样式管理
- 封面设计
- 视频/字幕/封面导出

## 技术栈

| 模块 | 技术 |
|---|---|
| UI | SwiftUI |
| 视频预览 | AVKit / AVFoundation |
| 素材读取 | AVFoundation |
| 文件系统 | Foundation / FileManager |
| 本地转写 | whisper.cpp |
| 视频导出 | FFmpeg (via Process) |
| 字幕格式 | SRT / ASS |
| 封面渲染 | CoreGraphics / SwiftUI Canvas |
| 配置文件 | JSON |

## 项目结构

```text
Sources/
  VlogPackApp/     — SwiftUI 壳与视图
  VlogPackCore/    — 核心数据模型与服务层
Tests/
  VlogPackCoreTests/
docs/              — 架构文档
```

## 构建

### 开发模式

```bash
swift build
swift test
```

### macOS App 打包

```bash
# 构建 .app bundle（内置 FFmpeg + Whisper.cpp）
./scripts/build-app.sh --release

# 创建 DMG 安装包
./scripts/package-dmg.sh --release
```

生成产物：
- `.build/release/VlogPack.app` — 可直接运行的 macOS 应用
- `.build/VlogPack-0.1.0-macOS.dmg` — 分发用 DMG 安装包

### 外部工具配置

| 工具 | 用途 | 内置状态 |
|---|---|---|
| FFmpeg | 视频处理、字幕烧录、导出 | ✅ 已内置 |
| FFprobe | 媒体信息读取 | ✅ 已内置 |
| whisper.cpp | 语音转文字 | ✅ 已内置（需下载模型） |

### Whisper 模型

语音转写功能需要下载 GGML 格式模型（首次使用时会提示下载）：

| 模型 | 大小 | 精度 | 推荐场景 |
|---|---|---|---|
| tiny | 75 MB | ★☆☆ | 快速预览 |
| base | 142 MB | ★★☆ | 日常使用（推荐） |
| small | 466 MB | ★★★ | 高精度转写 |
| medium | 1.4 GB | ★★★★ | 专业级 |
| large-v3 | 3.0 GB | ★★★★★ | 最高精度 |

模型存储在 `~/.vlogpack/whisper-models/`，可在设置页管理。

## 版本

- **v0.1-alpha**：项目系统 + 素材导入 + 时间线 + 无字幕导出
- **v0.1-beta**：转写 + 字幕编辑 + 字幕烧录
- **v0.1-rc**：封面 + 模板 + 完整发布资产导出

## 设计原则

1. **项目自包含** — 一个 Vlog = 一个项目文件夹，所有素材/缓存/字幕/封面/导出均在项目内
2. **本地优先** — 所有处理在本地完成，不默认上传素材
3. **品牌一致性内建** — 字幕样式、封面模板、Logo 设计是核心能力，不是附属功能
