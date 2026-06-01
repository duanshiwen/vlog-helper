import Foundation
import Testing
@testable import VlogPackCore

@Suite("TimelineService")
struct TimelineServiceTests {
    let service = TimelineService()

    private func makeProjectWithMedia() -> VlogProject {
        var project = VlogProject(projectName: "测试")
        project.migrateToMultiTrackIfNeeded()
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

    @Test("添加片段到视频轨道")
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

    @Test("视频轨片段不能重叠：向前拖动会吸附到前一个片段末尾")
    func testVideoClipCannotOverlapPreviousClip() throws {
        var project = makeProjectWithMedia()
        let item2 = MediaItem(id: "media-2", type: .video, originalFileName: "c2.mov", projectRelativePath: "media/original/clip_002.mov", duration: 10)
        project.mediaItems.append(item2)

        _ = try service.addClip(mediaItemId: "media-1", project: &project)
        let clip2 = try service.addClip(mediaItemId: "media-2", project: &project)

        try service.setStartTime(clipId: clip2.id, startTime: 20, project: &project)

        let updated = project.timeline.clip(byId: clip2.id)!
        #expect(updated.startTime == 30)
    }

    @Test("视频轨片段不能重叠：向后拖动会停在后一个片段前")
    func testVideoClipCannotOverlapNextClip() throws {
        var project = makeProjectWithMedia()
        let item2 = MediaItem(id: "media-2", type: .video, originalFileName: "c2.mov", projectRelativePath: "media/original/clip_002.mov", duration: 10)
        project.mediaItems.append(item2)

        let clip1 = try service.addClip(mediaItemId: "media-1", project: &project)
        _ = try service.addClip(mediaItemId: "media-2", project: &project)

        try service.setStartTime(clipId: clip1.id, startTime: 20, project: &project)

        let updated = project.timeline.clip(byId: clip1.id)!
        #expect(updated.startTime == 0)
    }

    @Test("添加字幕轨道")
    func testAddSubtitleTrack() {
        var project = makeProjectWithMedia()
        let track = service.addTrack(type: .subtitle, name: "字幕", project: &project)

        #expect(project.timeline.tracks.count == 2) // 默认视频 + 字幕
        #expect(track.type == .subtitle)
        #expect(track.name == "字幕")
    }

    @Test("添加字幕片段到字幕轨道")
    func testAddSubtitleClip() throws {
        var project = makeProjectWithMedia()
        let subtitleTrack = service.addTrack(type: .subtitle, project: &project)

        let clip = TimelineClip(
            mediaItemId: "subtitle",
            trackId: subtitleTrack.id,
            inPoint: 0,
            outPoint: 5,
            order: 0,
            subtitleText: "你好世界"
        )
        project.timeline.tracks[project.timeline.tracks.firstIndex(where: { $0.id == subtitleTrack.id })!].clips.append(clip)

        #expect(project.timeline.subtitleTrack?.clips.count == 1)
        #expect(project.timeline.subtitleTrack?.clips.first?.subtitleText == "你好世界")
    }

    @Test("删除字幕轨道")
    func testRemoveSubtitleTrack() {
        var project = makeProjectWithMedia()
        let track = service.addTrack(type: .subtitle, project: &project)
        service.removeTrack(trackId: track.id, project: &project)

        #expect(project.timeline.tracks.count == 1)
        #expect(project.timeline.subtitleTrack == nil)
    }

    @Test("切换静音")
    func testToggleMute() throws {
        var project = makeProjectWithMedia()
        let track = service.addTrack(type: .audio, project: &project)

        try service.toggleMute(trackId: track.id, project: &project)
        #expect(project.timeline.tracks.first { $0.type == .audio }?.isMuted == true)

        try service.toggleMute(trackId: track.id, project: &project)
        #expect(project.timeline.tracks.first { $0.type == .audio }?.isMuted == false)
    }

    @Test("跨轨道移动片段")
    func testMoveClipAcrossTracks() throws {
        var project = makeProjectWithMedia()
        let audioTrack = service.addTrack(type: .audio, project: &project)

        // 添加到视频轨道
        let clip = try service.addClip(mediaItemId: "media-1", project: &project)
        #expect(project.timeline.videoTrack?.clips.count == 1)

        // 移动到音频轨道
        try service.moveClip(clipId: clip.id, toTrack: audioTrack.id, project: &project)
        #expect(project.timeline.videoTrack?.clips.count == 0)
        #expect(project.timeline.audioTracks.first?.clips.count == 1)
    }
}
