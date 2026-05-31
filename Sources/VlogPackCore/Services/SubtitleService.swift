import Foundation

/// 字幕服务
public final class SubtitleService: @unchecked Sendable {
    public init() {}

    // MARK: - 初始化字幕文档

    /// 确保项目有字幕文档
    public func ensureSubtitleDocument(project: inout VlogProject) {
        if project.subtitles == nil {
            project.subtitles = SubtitleDocument()
        }
    }

    // MARK: - 编辑操作

    /// 编辑字幕文本
    public func updateText(
        segmentId: String,
        text: String,
        project: inout VlogProject
    ) {
        guard let index = project.subtitles?.segments
            .firstIndex(where: { $0.id == segmentId }) else { return }
        project.subtitles?.segments[index].text = text
    }

    /// 调整字幕开始时间
    public func updateStartTime(
        segmentId: String,
        start: Double,
        project: inout VlogProject
    ) {
        guard let index = project.subtitles?.segments
            .firstIndex(where: { $0.id == segmentId }) else { return }
        guard start >= 0 else { return }
        let seg = project.subtitles!.segments[index]
        if start < seg.end {
            project.subtitles?.segments[index].start = start
        }
    }

    /// 调整字幕结束时间
    public func updateEndTime(
        segmentId: String,
        end: Double,
        project: inout VlogProject
    ) {
        guard let index = project.subtitles?.segments
            .firstIndex(where: { $0.id == segmentId }) else { return }
        let seg = project.subtitles!.segments[index]
        if end > seg.start {
            project.subtitles?.segments[index].end = end
        }
    }

    /// 合并当前字幕和下一条
    public func mergeWithNext(
        segmentId: String,
        project: inout VlogProject
    ) {
        guard var segments = project.subtitles?.segments,
              let index = segments.firstIndex(where: { $0.id == segmentId }),
              index + 1 < segments.count else { return }

        let current = segments[index]
        let next = segments[index + 1]

        segments[index].end = next.end
        segments[index].text = current.text + next.text
        segments.remove(at: index + 1)

        project.subtitles?.segments = segments
    }

    /// 拆分字幕：在指定时间点拆分为两条
    public func splitSegment(
        segmentId: String,
        at splitTime: Double,
        project: inout VlogProject
    ) {
        guard var segments = project.subtitles?.segments,
              let index = segments.firstIndex(where: { $0.id == segmentId }) else { return }

        let seg = segments[index]
        guard splitTime > seg.start && splitTime < seg.end else { return }

        // 简单按中间点拆分文本
        let midIndex = seg.text.index(seg.text.startIndex, offsetBy: seg.text.count / 2)
        let firstText = String(seg.text[..<midIndex])
        let secondText = String(seg.text[midIndex...])

        segments[index].end = splitTime
        segments[index].text = firstText

        let newSeg = SubtitleSegment(
            start: splitTime,
            end: seg.end,
            text: secondText
        )
        segments.insert(newSeg, at: index + 1)

        project.subtitles?.segments = segments
    }

    // MARK: - 删除字幕

    public func deleteSegment(
        segmentId: String,
        project: inout VlogProject
    ) {
        project.subtitles?.segments.removeAll { $0.id == segmentId }
    }

    // MARK: - 搜索

    public func searchSegments(
        query: String,
        project: VlogProject
    ) -> [SubtitleSegment] {
        guard !query.isEmpty else { return [] }
        return project.subtitles?.segments.filter {
            $0.text.localizedCaseInsensitiveContains(query)
        } ?? []
    }

    // MARK: - 时间轴跳转

    /// 点击字幕时返回对应的开始时间
    public func startTime(forSegment segmentId: String, project: VlogProject) -> Double? {
        project.subtitles?.segments.first { $0.id == segmentId }?.start
    }

    // MARK: - 导出格式

    /// 导出为 SRT 格式
    public func exportSRT(project: VlogProject) -> String {
        guard let segments = project.subtitles?.segments else { return "" }

        var srt = ""
        for (index, seg) in segments.enumerated() {
            srt += "\(index + 1)\n"
            srt += "\(formatSRTTime(seg.start)) --> \(formatSRTTime(seg.end))\n"
            srt += "\(seg.text)\n\n"
        }
        return srt
    }

    /// 导出为 ASS 格式
    public func exportASS(project: VlogProject) -> String {
        guard let subtitles = project.subtitles else { return "" }
        let style = subtitles.style
        let segments = subtitles.segments

        let header = """
        [Script Info]
        Title: VlogPack Subtitles
        ScriptType: v4.00+
        PlayResX: \(project.resolution.width)
        PlayResY: \(project.resolution.height)
        WrapStyle: 0

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,\(style.fontFamily),\(Int(style.fontSize)),\(assColor(style.textColor)),&H000000FF,\(assColor(style.outlineColor)),&H80000000,0,0,0,0,100,100,0,0,1,\(Int(style.outlineWidth)),2,\(assAlignment(style.position)),40,40,\(Int(style.marginBottom)),1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        """

        var events: [String] = []
        for seg in segments {
            let start = formatASSTime(seg.start)
            let end = formatASSTime(seg.end)
            let text = seg.text.replacingOccurrences(of: "\n", with: "\\N")
            events.append("Dialogue: 0,\(start),\(end),Default,,0,0,0,,\(text)")
        }

        return header + "\n" + events.joined(separator: "\n") + "\n"
    }

    // MARK: - 时间格式化

    private func formatSRTTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds - Double(Int(seconds))) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    private func formatASSTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        let cs = Int((seconds - Double(Int(seconds))) * 100)
        return String(format: "%d:%02d:%02d.%02d", h, m, s, cs)
    }

    private func assColor(_ hex: String) -> String {
        // #RRGGBB → &H00BBGGRR (ASS format)
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6 else { return "&H00FFFFFF" }
        let r = String(cleaned.prefix(2))
        let g = String(cleaned.dropFirst(2).prefix(2))
        let b = String(cleaned.dropFirst(4).prefix(2))
        return "&H00\(b)\(g)\(r)"
    }

    private func assAlignment(_ position: SubtitlePosition) -> Int {
        switch position {
        case .bottomCenter: return 2
        case .topCenter: return 8
        case .center: return 5
        }
    }
}
