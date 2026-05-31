import Foundation

/// 简单日志工具，后续可扩展为文件日志
public enum VlogPackLog {
    public static func info(_ message: String) {
        print("[VlogPack] \(message)")
    }

    public static func error(_ message: String) {
        print("[VlogPack ERROR] \(message)")
    }
}
