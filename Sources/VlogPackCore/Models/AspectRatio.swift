import Foundation

/// 宽高比枚举
public enum AspectRatio: String, Codable, Sendable, CaseIterable {
    case landscape16x9 = "16:9"

    public var widthFactor: Int {
        switch self {
        case .landscape16x9: return 16
        }
    }

    public var heightFactor: Int {
        switch self {
        case .landscape16x9: return 9
        }
    }
}
