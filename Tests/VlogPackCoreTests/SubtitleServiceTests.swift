import Foundation
import Testing
@testable import VlogPackCore

@Suite("SubtitleService")
struct SubtitleServiceTests {
    let service = SubtitleService()

    private func makeProjectWithSubtitles() -> VlogProject {
        var project = VlogProject(projectName: "字幕测试")
        let doc = SubtitleDocument(segments: [
            SubtitleSegment(id: "s1", start: 0, end: 2.5, text: "你好世界"),
            SubtitleSegment(id: "s2", start: 2.5, end: 5.0, text: "这是测试"),
            SubtitleSegment(id: "s3", start: 5.0, end: 8.0, text: "第三条字幕"),
        ])
        project.subtitles = doc
        return project
    }

    @Test("编辑字幕文本")
    func testUpdateText() {
        var project = makeProjectWithSubtitles()
        service.updateText(segmentId: "s1", text: "你好 VlogPack", project: &project)
        #expect(project.subtitles?.segments.first?.text == "你好 VlogPack")
    }

    @Test("合并字幕")
    func testMergeWithNext() {
        var project = makeProjectWithSubtitles()
        service.mergeWithNext(segmentId: "s1", project: &project)

        let segments = project.subtitles?.segments ?? []
        #expect(segments.count == 2)
        #expect(segments[0].text == "你好世界这是测试")
        #expect(segments[0].end == 5.0)
    }

    @Test("删除字幕")
    func testDeleteSegment() {
        var project = makeProjectWithSubtitles()
        service.deleteSegment(segmentId: "s2", project: &project)
        #expect(project.subtitles?.segments.count == 2)
        #expect(project.subtitles?.segments.first?.id == "s1")
    }

    @Test("搜索字幕")
    func testSearchSegments() {
        let project = makeProjectWithSubtitles()
        let results = service.searchSegments(query: "测试", project: project)
        #expect(results.count == 1)
        #expect(results.first?.text == "这是测试")
    }

    @Test("导出 SRT 格式")
    func testExportSRT() {
        let project = makeProjectWithSubtitles()
        let srt = service.exportSRT(project: project)

        #expect(srt.contains("1\n"))
        #expect(srt.contains("00:00:00,000 --> 00:00:02,500"))
        #expect(srt.contains("你好世界"))
        #expect(srt.contains("2\n"))
        #expect(srt.contains("00:00:02,500 --> 00:00:05,000"))
        #expect(srt.contains("这是测试"))
    }

    @Test("导出 ASS 格式")
    func testExportASS() {
        var project = makeProjectWithSubtitles()
        project.subtitles?.style = SubtitleStyle(
            fontFamily: "PingFang SC",
            fontSize: 48,
            textColor: "#FFFFFF",
            outlineColor: "#000000"
        )

        let ass = service.exportASS(project: project)

        #expect(ass.contains("[Script Info]"))
        #expect(ass.contains("[V4+ Styles]"))
        #expect(ass.contains("PingFang SC"))
        #expect(ass.contains("[Events]"))
        #expect(ass.contains("你好世界"))
        #expect(ass.contains("Dialogue:"))
    }

    @Test("拆分字幕")
    func testSplitSegment() {
        var project = makeProjectWithSubtitles()
        service.splitSegment(segmentId: "s1", at: 1.2, project: &project)

        let segments = project.subtitles?.segments ?? []
        #expect(segments.count == 4)
        // 拆分后的前半段
        #expect(segments[0].end == 1.2)
        // 拆分后的后半段
        #expect(segments[1].start == 1.2)
        #expect(segments[1].end == 2.5)
    }
}
