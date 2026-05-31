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

```bash
swift build
swift test
```

## 版本

- **v0.1-alpha**：项目系统 + 素材导入 + 时间线 + 无字幕导出
- **v0.1-beta**：转写 + 字幕编辑 + 字幕烧录
- **v0.1-rc**：封面 + 模板 + 完整发布资产导出

## 设计原则

1. **项目自包含** — 一个 Vlog = 一个项目文件夹，所有素材/缓存/字幕/封面/导出均在项目内
2. **本地优先** — 所有处理在本地完成，不默认上传素材
3. **品牌一致性内建** — 字幕样式、封面模板、Logo 设计是核心能力，不是附属功能
