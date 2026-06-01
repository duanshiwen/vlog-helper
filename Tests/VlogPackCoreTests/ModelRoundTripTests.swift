import Foundation
import Testing
@testable import VlogPackCore

@Suite("Model Codable Round-Trip")
struct ModelRoundTripTests {

    /// 从 clips 创建带默认视频轨道的 Timeline
    private func makeTimeline(clips: [TimelineClip]) -> Timeline {
        let track = Track(name: "主视频", type: .video, clips: clips, order: 0)
        return Timeline(tracks: [track])
    }

    @Test("VlogProject 可以 JSON round-trip")
    func testVlogProjectRoundTrip() throws {
        let project = VlogProject(
            projectName: "测试项目",
            mediaItems: [
                MediaItem(
                    id: "m1",
                    type: .video,
                    originalFileName: "clip.MOV",
                    projectRelativePath: "media/original/clip_001.mov",
                    duration: 12.5,
                    width: 1920,
                    height: 1080,
                    frameRate: 30.0
                )
            ],
            timeline: makeTimeline(clips: [
                TimelineClip(
                    id: "c1",
                    mediaItemId: "m1",
                    inPoint: 0,
                    outPoint: 12.5,
                    order: 0
                )
            ]),
            subtitles: SubtitleDocument(
                segments: [
                    SubtitleSegment(start: 0, end: 2.5, text: "你好"),
                    SubtitleSegment(start: 2.5, end: 5.0, text: "世界"),
                ],
                style: SubtitleStyle()
            )
        )

        // Encode
        let data = try JSONEncoder.iso8601.encode(project)
        // Decode
        let decoded = try JSONDecoder.iso8601.decode(VlogProject.self, from: data)

        #expect(decoded.projectId == project.projectId)
        #expect(decoded.projectName == "测试项目")
        #expect(decoded.mediaItems.count == 1)
        #expect(decoded.mediaItems.first?.originalFileName == "clip.MOV")
        #expect(decoded.timeline.clips.count == 1)
        #expect(decoded.subtitles?.segments.count == 2)
        #expect(decoded.subtitles?.segments.first?.text == "你好")
    }

    @Test("TimelineClip duration 计算正确")
    func testTimelineClipDuration() {
        let clip = TimelineClip(
            mediaItemId: "m1",
            inPoint: 5.0,
            outPoint: 12.5,
            order: 0
        )
        #expect(clip.duration == 7.5)
    }

    @Test("TimelineClip duration：outPoint < inPoint 返回 0")
    func testTimelineClipDurationNegative() {
        let clip = TimelineClip(
            mediaItemId: "m1",
            inPoint: 15.0,
            outPoint: 10.0,
            order: 0
        )
        #expect(clip.duration == 0)
    }

    @Test("Timeline totalDuration")
    func testTimelineTotalDuration() {
        let timeline = makeTimeline(clips: [
            TimelineClip(mediaItemId: "m1", inPoint: 0, outPoint: 10, order: 0),
            TimelineClip(mediaItemId: "m2", inPoint: 0, outPoint: 5.5, order: 1),
            TimelineClip(mediaItemId: "m3", inPoint: 2, outPoint: 8, order: 2),
        ])
        // clip1: 0→10 = 10s, clip2: 0→5.5 = 5.5s, clip3: 2→8 = 6s
        #expect(timeline.totalDuration == 21.5)
    }

    @Test("Timeline sortedClips 按 order 排序")
    func testTimelineSortedClips() {
        let timeline = makeTimeline(clips: [
            TimelineClip(mediaItemId: "m1", order: 2),
            TimelineClip(mediaItemId: "m2", order: 0),
            TimelineClip(mediaItemId: "m3", order: 1),
        ])
        let sorted = timeline.sortedClips
        #expect(sorted[0].order == 0)
        #expect(sorted[1].order == 1)
        #expect(sorted[2].order == 2)
    }

    @Test("SubtitleSegment duration")
    func testSubtitleDuration() {
        let seg = SubtitleSegment(start: 1.0, end: 3.5, text: "Hello")
        #expect(seg.duration == 2.5)
    }

    @Test("多轨 Timeline round-trip")
    func testMultiTrackTimelineRoundTrip() throws {
        let videoTrack = Track(
            name: "主视频", type: .video,
            clips: [TimelineClip(mediaItemId: "m1", trackId: "vt", inPoint: 0, outPoint: 10, order: 0)],
            order: 0
        )
        let subtitleTrack = Track(
            name: "字幕", type: .subtitle,
            clips: [TimelineClip(mediaItemId: "subtitle", trackId: "st", inPoint: 0, outPoint: 5, order: 0, subtitleText: "你好")],
            order: 1
        )
        let timeline = Timeline(tracks: [videoTrack, subtitleTrack])

        let data = try JSONEncoder.iso8601.encode(timeline)
        let decoded = try JSONDecoder.iso8601.decode(Timeline.self, from: data)

        #expect(decoded.tracks.count == 2)
        #expect(decoded.tracks[0].type == .video)
        #expect(decoded.tracks[1].type == .subtitle)
        #expect(decoded.tracks[1].clips.first?.subtitleText == "你好")
        #expect(decoded.videoTrack?.clips.count == 1)
        #expect(decoded.subtitleTrack?.clips.count == 1)
    }

    @Test("旧 JSON 格式（timeline.clips 无 tracks）可以正确解码")
    func testOldJSONFormatDecoding() throws {
        // 模拟旧版 project.vlogpack.json 的 timeline 部分
        let json = """
        {
          "clips": [
            {
              "id": "clip-1",
              "mediaItemId": "media-1",
              "inPoint": 0,
              "outPoint": 10,
              "order": 0
            }
          ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Timeline.self, from: data)
        
        // 应该自动创建视频轨道并放入旧 clips
        #expect(decoded.tracks.count == 1)
        #expect(decoded.tracks[0].type == .video)
        #expect(decoded.tracks[0].name == "主视频")
        #expect(decoded.tracks[0].clips.count == 1)
        #expect(decoded.tracks[0].clips[0].id == "clip-1")
        #expect(decoded.videoTrack?.clips.count == 1)
    }

    @Test("v0.1 → v0.2 迁移")
    func testMigrationFromV01() {
        // 模拟旧版 Timeline（只有 clips，没有 tracks）
        let oldClips = [
            TimelineClip(mediaItemId: "m1", inPoint: 0, outPoint: 10, order: 0)
        ]
        let videoTrack = Track(name: "主视频", type: .video, clips: oldClips, order: 0)
        var project = VlogProject(
            schemaVersion: "0.1.0",
            projectName: "旧项目",
            timeline: Timeline(tracks: [videoTrack])
        )

        project.migrateToMultiTrackIfNeeded()

        #expect(project.schemaVersion == "0.2.0")
        #expect(project.timeline.tracks.count == 1)
        #expect(project.timeline.tracks[0].type == .video)
        #expect(project.timeline.clips.count == 1)
    }
}

// MARK: - JSON Encoder/Decoder helpers

extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
