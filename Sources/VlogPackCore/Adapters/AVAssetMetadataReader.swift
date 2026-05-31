import Foundation
import AVFoundation
#if canImport(AppKit)
import AppKit
#endif

/// 素材元数据读取结果
public struct MediaMetadata: Sendable {
    public let duration: Double
    public let width: Int
    public let height: Int
    public let frameRate: Double

    public init(duration: Double, width: Int, height: Int, frameRate: Double) {
        self.duration = duration
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }
}

/// AVFoundation 元数据读取
public enum AVAssetMetadataReader {
    /// 读取视频文件元数据（同步）
    public static func readMetadata(from url: URL) throws -> MediaMetadata {
        let asset = AVURLAsset(url: url)

        // 读取时长
        let durationValue: Double
        do {
            let duration = try loadDuration(asset)
            durationValue = duration
        } catch {
            durationValue = 0
        }

        // 读取视频轨道信息
        let tracks = asset.tracks(withMediaType: .video)
        if let track = tracks.first {
            let size = track.naturalSize.applying(track.preferredTransform)
            let width = Int(abs(size.width))
            let height = Int(abs(size.height))
            let fps = Float64(track.nominalFrameRate)
            return MediaMetadata(
                duration: durationValue,
                width: width,
                height: height,
                frameRate: fps
            )
        }

        // 无视频轨（纯音频或图片）
        return MediaMetadata(
            duration: durationValue,
            width: 0,
            height: 0,
            frameRate: 0
        )
    }

    private static func loadDuration(_ asset: AVURLAsset) throws -> Double {
        // CMTime 使用同步方式获取
        // 对于本地文件这是安全的
        let duration = asset.duration
        guard duration.isValid && !duration.isIndefinite else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }

    /// 从视频指定时间点生成缩略图
    public static func generateThumbnail(
        from url: URL,
        at time: Double,
        maxSize: CGSize = CGSize(width: 320, height: 180)
    ) throws -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let imageResult = try generator.copyCGImage(at: cmTime, actualTime: nil)

        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: imageResult)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        #else
        return nil
        #endif
    }

    /// 从视频多个时间点批量生成缩略图
    public static func generateThumbnails(
        from url: URL,
        at times: [Double],
        maxSize: CGSize = CGSize(width: 320, height: 180)
    ) throws -> [Data] {
        var results: [Data] = []
        for time in times {
            if let data = try generateThumbnail(from: url, at: time, maxSize: maxSize) {
                results.append(data)
            }
        }
        return results
    }
}
