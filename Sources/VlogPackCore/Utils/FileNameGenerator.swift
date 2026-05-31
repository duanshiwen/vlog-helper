import Foundation

/// 文件名生成器：标准化项目与素材命名
public enum FileNameGenerator {
    /// 将项目名转换为文件夹 slug
    /// 输入: "杭州日更 Vlog" → 输出: "2026-06-01-hangzhou-ri-geng-vlog"
    public static func projectFolderName(
        projectName: String,
        date: Date = Date()
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = dateFormatter.string(from: date)

        let slug = slugify(projectName)
        return "\(dateStr)-\(slug)"
    }

    /// 素材文件标准化名
    /// - Parameters:
    ///   - prefix: 如 "clip", "image", "logo"
    ///   - index: 序号
    ///   - pathExtension: 如 "mov", "jpg", "png"
    public static func mediaFileName(prefix: String, index: Int, pathExtension: String) -> String {
        let padded = String(format: "%03d", index)
        return "\(prefix)_\(padded).\(pathExtension)"
    }

    /// 将任意文本 slugify：去中文特殊字符、转小写、连字符分隔
    static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        // 保留字母、数字、中文字符；其他替换为连字符
        var result = ""
        var lastWasSeparator = false

        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar)
                || isChineseCharacter(scalar)
            {
                result.append(Character(scalar))
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }

        // 清理首尾连字符
        let cleaned = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "untitled" : cleaned
    }

    /// 简单判断中文字符范围
    private static func isChineseCharacter(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value)       // CJK Unified
            || (0x3400...0x4DBF).contains(scalar.value) // CJK Extension A
            || (0xF900...0xFAFF).contains(scalar.value) // CJK Compat
    }
}
