import Foundation

/// Whisper 模型规格
public struct WhisperModelSpec: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let sizeMB: Int
    public let url: String
    public let description: String

    public init(id: String, name: String, sizeMB: Int, url: String, description: String) {
        self.id = id
        self.name = name
        self.sizeMB = sizeMB
        self.url = url
        self.description = description
    }
}

/// Whisper 模型管理器
/// 管理 whisper.cpp 模型的下载、存储和状态检查
public final class WhisperModelManager: @unchecked Sendable {
    /// 内置模型列表（ggml 格式，适用于 whisper.cpp）
    public static let builtinModels: [WhisperModelSpec] = [
        WhisperModelSpec(
            id: "tiny",
            name: "Tiny",
            sizeMB: 75,
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
            description: "最快，精度最低，适合快速预览"
        ),
        WhisperModelSpec(
            id: "base",
            name: "Base",
            sizeMB: 142,
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
            description: "平衡速度和精度，推荐日常使用"
        ),
        WhisperModelSpec(
            id: "small",
            name: "Small",
            sizeMB: 466,
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            description: "精度较高，速度适中"
        ),
        WhisperModelSpec(
            id: "medium",
            name: "Medium",
            sizeMB: 1456,
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
            description: "高精度，需要较多内存"
        ),
        WhisperModelSpec(
            id: "large-v3",
            name: "Large v3",
            sizeMB: 3095,
            url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin",
            description: "最高精度，需要大量内存和时间"
        ),
    ]

    private let modelsDir: URL

    public init(modelsDir: URL? = nil) {
        if let dir = modelsDir {
            self.modelsDir = dir
        } else {
            // 默认存储在 ~/.vlogpack/whisper-models/
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.modelsDir = home.appendingPathComponent(".vlogpack/whisper-models")
        }
    }

    /// 获取模型文件路径
    public func modelPath(for spec: WhisperModelSpec) -> URL {
        modelsDir.appendingPathComponent("ggml-\(spec.id).bin")
    }

    /// 检查模型是否已下载
    public func isModelDownloaded(_ spec: WhisperModelSpec) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: spec).path)
    }

    /// 获取已下载的模型列表
    public func downloadedModels() -> [WhisperModelSpec] {
        Self.builtinModels.filter { isModelDownloaded($0) }
    }

    /// 下载模型，返回进度回调
    public func downloadModel(
        _ spec: WhisperModelSpec,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // 确保目录存在
        try FileManager.default.createDirectory(
            at: modelsDir,
            withIntermediateDirectories: true
        )

        let destURL = modelPath(for: spec)
        let tempURL = destURL.appendingPathExtension("tmp")

        guard let url = URL(string: spec.url) else {
            throw WhisperModelError.invalidURL(spec.url)
        }

        // 使用 URLSession downloadTask 式下载
        let (tempFileURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WhisperModelError.downloadFailed("HTTP 错误")
        }

        onProgress(1.0)

        // 移动到目标位置
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempFileURL, to: destURL)

        return destURL

        // 移动到最终位置
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        return destURL
    }

    /// 删除模型
    public func deleteModel(_ spec: WhisperModelSpec) throws {
        let path = modelPath(for: spec)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
}

/// Whisper 模型管理错误
public enum WhisperModelError: LocalizedError {
    case invalidURL(String)
    case downloadFailed(String)
    case modelNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "无效的下载地址: \(url)"
        case .downloadFailed(let reason): return "下载失败: \(reason)"
        case .modelNotFound(let name): return "模型不存在: \(name)"
        }
    }
}
