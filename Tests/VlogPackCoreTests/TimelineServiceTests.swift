import Foundation
import Testing
@testable import VlogPackCore

@Suite("TimelineService")
struct TimelineServiceTests {
    let service = TimelineService()

    private func makeProjectWithMedia() -> VlogProject {
        var project = VlogProject(projectName: "测试")
        let item = MediaItem(
            id: "media-1",
            type: .video,
            originalFileName: "clip.mov",
            projectRelativePath: "media/original/clip_001.mov",
            duration: 30.0,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
        project.mediaItems = [item]
        return project
    }

    @Test("添加片段到时间线")
    func testAddClip() throws {
        var project = makeProjectWithMedia()
        let clip = try service.addClip(mediaItemId: "media-1", project: &project)

        #expect(project.timeline.clips.count == 1)
        #expect(clip.mediaItemId == "media-1")
        #expect(clip.outPoint == 30.0)
        #expect(clip.order == 0)
    }

    @Test("删除片段")
    func testRemoveClip() throws {
        var project = makeProjectWithMedia()
        let clip = try service.addClip(mediaItemId: "media-1", project: &project)
        service.removeClip(clipId: clip.id, project: &project)

        #expect(project.timeline.clips.isEmpty)
    }

    @Test("总时长计算")
    func testTotalDuration() throws {
        var project = makeProjectWithMedia()
        // 添加第二个素材
        let item2 = MediaItem(
            id: "media-2",
            type: .video,
            originalFileName: "clip2.mov",
            projectRelativePath: "media/original/clip_002.mov",
            duration: 15.0
        )
        project.mediaItems.append(item2)

        try service.addClip(mediaItemId: "media-1", project: &project)
        try service.addClip(mediaItemId: "media-2", project: &project)

        #expect(service.totalDuration(project: project) == 45.0)
    }

    @Test("设置入点")
    func testSetInPoint() throws {
        var project = makeProjectWithMedia()
        let clip = try service.addClip(mediaItemId: "media-1", project: &project)

        try service.setInPoint(clipId: clip.id, inPoint: 5.0, project: &project)
        let updated = project.timeline.clips.first!
        #expect(updated.inPoint == 5.0)
    }

    @Test("入点不能超过出点")
    func testInvalidInPoint() throws {
        var project = makeProjectWithMedia()
        let clip = try service.addClip(mediaItemId: "media-1", project: &project)

        #expect(throws: TimelineServiceError.self) {
            try service.setInPoint(clipId: clip.id, inPoint: 35.0, project: &project)
        }
    }

    @Test("移动片段")
    func testMoveClip() throws {
        var project = makeProjectWithMedia()
        let item2 = MediaItem(id: "media-2", type: .video, originalFileName: "c2.mov", projectRelativePath: "media/original/clip_002.mov", duration: 10)
        project.mediaItems.append(item2)

        let clip1 = try service.addClip(mediaItemId: "media-1", project: &project)
        _ = try service.addClip(mediaItemId: "media-2", project: &project)

        try service.moveClip(clipId: clip1.id, to: 1, project: &project)

        #expect(project.timeline.sortedClips[0].mediaItemId == "media-2")
        #expect(project.timeline.sortedClips[1].mediaItemId == "media-1")
    }
}
