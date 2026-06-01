import Foundation

/// 分辨率
public struct Resolution: Codable, Sendable, Equatable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// 默认 1080p
    public static let hd1080 = Resolution(width: 1920, height: 1080)
}
