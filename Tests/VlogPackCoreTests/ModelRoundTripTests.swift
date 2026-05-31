import Foundation
import Testing
@testable import VlogPackCore

@Suite("Model Codable Round-Trip")
struct ModelRoundTripTests {

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
            timeline: Timeline(clips: [
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
        let timeline = Timeline(clips: [
            TimelineClip(mediaItemId: "m1", inPoint: 0, outPoint: 10, order: 0),
            TimelineClip(mediaItemId: "m2", inPoint: 0, outPoint: 5.5, order: 1),
            TimelineClip(mediaItemId: "m3", inPoint: 2, outPoint: 8, order: 2),
        ])
        // clip1: 0→10 = 10s, clip2: 0→5.5 = 5.5s, clip3: 2→8 = 6s
        #expect(timeline.totalDuration == 21.5)
    }

    @Test("Timeline sortedClips 按 order 排序")
    func testTimelineSortedClips() {
        let timeline = Timeline(clips: [
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
