import Foundation
import Testing
@testable import VlogPackCore

@Suite("TemplateService")
struct TemplateServiceTests {
    let service = TemplateService()

    @Test("内置字幕模板数量")
    func testBuiltinSubtitleTemplates() {
        let templates = service.builtinSubtitleTemplates
        #expect(templates.count >= 3)
        #expect(templates["daily-clean"] != nil)
        #expect(templates["bold-vlog"] != nil)
        #expect(templates["documentary"] != nil)
    }

    @Test("内置封面模板数量")
    func testBuiltinCoverTemplates() {
        let templates = service.builtinCoverTemplates
        #expect(templates.count >= 3)
        #expect(templates["daily-travel"] != nil)
        #expect(templates["city-walk"] != nil)
    }

    @Test("应用字幕模板到项目")
    func testApplySubtitleTemplate() {
        var project = VlogProject(projectName: "模板测试")
        let style = service.builtinSubtitleTemplates["bold-vlog"]!

        service.applySubtitleTemplate(style, project: &project)

        #expect(project.subtitles?.style.fontFamily == style.fontFamily)
        #expect(project.subtitles?.style.fontSize == style.fontSize)
        #expect(project.subtitles?.style.textColor == style.textColor)
    }

    @Test("应用封面模板到项目")
    func testApplyCoverTemplate() {
        var project = VlogProject(projectName: "封面模板测试")
        let style = service.builtinCoverTemplates["city-walk"]!

        service.applyCoverTemplate(style, project: &project)

        #expect(project.cover?.textStyle.fontFamily == style.fontFamily)
        #expect(project.cover?.textStyle.fontSize == style.fontSize)
    }

    @Test("保存和加载自定义字幕模板")
    func testSaveLoadSubtitleTemplate() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vlogpack-template-test-\(UUID().uuidString)")
        let templateService = TemplateService(templatesDir: tmpDir)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let style = SubtitleStyle(
            fontFamily: "Custom Font",
            fontSize: 52,
            textColor: "#FF0000"
        )

        try templateService.saveSubtitleTemplate(name: "my-style", style: style)
        let loaded = try templateService.loadSubtitleTemplate(name: "my-style")

        #expect(loaded.fontFamily == "Custom Font")
        #expect(loaded.fontSize == 52)
        #expect(loaded.textColor == "#FF0000")
    }
}
