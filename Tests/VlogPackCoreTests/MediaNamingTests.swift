import Foundation
import Testing
@testable import VlogPackCore

@Suite("FileNameGenerator")
struct MediaNamingTests {

    @Test("项目文件夹名：包含日期和 slug")
    func testProjectFolderName() {
        let date = makeFixedDate()
        let name = FileNameGenerator.projectFolderName(
            projectName: "杭州日更 Vlog",
            date: date
        )
        // slugify 保留中文字符，不转拼音
        #expect(name == "2026-06-01-杭州日更-vlog")
    }

    @Test("项目文件夹名：纯英文输入")
    func testProjectFolderNameEnglish() {
        let date = makeFixedDate()
        let name = FileNameGenerator.projectFolderName(
            projectName: "Daily Travel Vlog",
            date: date
        )
        #expect(name == "2026-06-01-daily-travel-vlog")
    }

    @Test("项目文件夹名：空字符串回退到 untitled")
    func testProjectFolderNameEmpty() {
        let name = FileNameGenerator.projectFolderName(projectName: "")
        #expect(name.hasSuffix("-untitled"))
    }

    @Test("素材文件名：格式正确")
    func testMediaFileName() {
        let name = FileNameGenerator.mediaFileName(
            prefix: "clip",
            index: 1,
            pathExtension: "mov"
        )
        #expect(name == "clip_001.mov")
    }

    @Test("素材文件名：序号补零到三位")
    func testMediaFileNamePadding() {
        let name = FileNameGenerator.mediaFileName(
            prefix: "image",
            index: 12,
            pathExtension: "jpg"
        )
        #expect(name == "image_012.jpg")
    }

    @Test("素材文件名：logo 类型")
    func testLogoFileName() {
        let name = FileNameGenerator.mediaFileName(
            prefix: "logo",
            index: 1,
            pathExtension: "png"
        )
        #expect(name == "logo_001.png")
    }
}

private func makeFixedDate() -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    return Calendar.current.date(from: components) ?? Date()
}
