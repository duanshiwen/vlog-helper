# VlogPack 项目文件格式

## `project.vlogpack.json` Schema

顶层字段：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `schemaVersion` | String | 是 | 语义化版本，如 `"0.1.0"` |
| `projectId` | String | 是 | UUID |
| `projectName` | String | 是 | 用户输入的项目名 |
| `createdAt` | Date (ISO 8601) | 是 | 创建时间 |
| `updatedAt` | Date (ISO 8601) | 是 | 最后修改时间 |
| `aspectRatio` | String | 是 | `"16:9"` |
| `resolution` | Object | 是 | `{ "width": 1920, "height": 1080 }` |
| `mediaItems` | [MediaItem] | 是 | 素材列表 |
| `timeline` | Timeline | 是 | 时间线 |
| `subtitles` | SubtitleDocument? | 否 | 字幕文档 |
| `cover` | CoverDesign? | 否 | 封面设计 |
| `exportSettings` | ExportSettings | 是 | 导出设置 |

## MediaItem

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 唯一标识 |
| `type` | String | `"video"`, `"image"`, `"logo"` |
| `originalFileName` | String | 原始文件名 |
| `projectRelativePath` | String | 项目内相对路径 |
| `duration` | Double | 时长（秒），图片为 0 |
| `width` | Int | 宽度像素 |
| `height` | Int | 高度像素 |
| `frameRate` | Double | 帧率 |
| `createdAt` | Date | 导入时间 |

## Timeline

| 字段 | 类型 | 说明 |
|---|---|---|
| `clips` | [TimelineClip] | 片段列表 |

## TimelineClip

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 唯一标识 |
| `mediaItemId` | String | 关联素材 ID |
| `inPoint` | Double | 入点（秒） |
| `outPoint` | Double | 出点（秒） |
| `order` | Int | 排序序号 |

## SubtitleDocument

| 字段 | 类型 | 说明 |
|---|---|---|
| `segments` | [SubtitleSegment] | 字幕片段 |
| `style` | SubtitleStyle | 字幕样式 |
| `srtPath` | String? | SRT 导出相对路径 |
| `assPath` | String? | ASS 导出相对路径 |

## SubtitleSegment

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 唯一标识 |
| `start` | Double | 开始时间（秒） |
| `end` | Double | 结束时间（秒） |
| `text` | String | 字幕文本 |

## SubtitleStyle

| 字段 | 类型 | 说明 |
|---|---|---|
| `fontFamily` | String | 字体名 |
| `fontSize` | Double | 字号 |
| `textColor` | String | 文字颜色（Hex） |
| `outlineColor` | String | 描边颜色 |
| `outlineWidth` | Double | 描边宽度 |
| `shadowColor` | String | 阴影颜色 |
| `shadowOpacity` | Double | 阴影透明度 |
| `shadowOffsetX` | Double | 阴影 X 偏移 |
| `shadowOffsetY` | Double | 阴影 Y 偏移 |
| `position` | String | `"bottom-center"` 等 |
| `marginBottom` | Double | 底部安全边距 |
| `maxLineWidth` | Double | 最大行宽比例 |

## CoverDesign

| 字段 | 类型 | 说明 |
|---|---|---|
| `sourceType` | String | `"video-frame"` 或 `"manual"` |
| `sourcePath` | String | 背景图相对路径 |
| `title` | String | 封面标题 |
| `textStyle` | Object | 标题样式 |
| `logoPath` | String? | Logo 相对路径 |
| `logoFrame` | Object? | Logo 位置与尺寸 |
| `backgroundTransform` | Object | 背景变换 |
| `outputPath` | String? | 导出路径 |

## ExportSettings

| 字段 | 类型 | 说明 |
|---|---|---|
| `resolution` | Object | `{ "width": 1920, "height": 1080 }` |
| `format` | String | `"mp4"` |
| `videoCodec` | String | `"h264"` |
| `audioCodec` | String | `"aac"` |
| `burnSubtitles` | Bool | 是否烧录字幕 |
| `outputPath` | String | 导出相对路径 |

## 版本演进

| 版本 | 说明 |
|---|---|
| `0.1.0` | 初始 schema，v0.1 MVP |

`schemaVersion` 用于后续迁移脚本识别项目格式版本。
