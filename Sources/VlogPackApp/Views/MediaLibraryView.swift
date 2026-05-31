import SwiftUI
import VlogPackCore
import AVKit

/// 素材库视图
struct MediaLibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var mediaService = MediaService()

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("素材库")
                    .font(.headline)
                Spacer()
                Text("\(appState.currentProject?.mediaItems.count ?? 0) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            // 素材列表
            if let project = appState.currentProject {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120), spacing: 8)
                    ], spacing: 8) {
                        ForEach(project.mediaItems) { item in
                            MediaItemCard(
                                item: item,
                                projectRoot: appState.currentProjectRoot!
                            )
                            .contextMenu {
                                Button("添加到时间线") {
                                    addToTimeline(item)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    deleteItem(item)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            } else {
                Spacer()
                Text("未打开项目")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            // 底部提示
            Text("拖入视频/图片素材")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 拖拽导入

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let root = appState.currentProjectRoot,
              appState.currentProject != nil else { return false }

        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    do {
                        try mediaService.importMedia(
                            sourceURL: url,
                            projectRoot: root,
                            project: &appState.currentProject!
                        )
                        try? appState.saveCurrentProject()
                    } catch {
                        VlogPackLog.error("Import failed: \(error)")
                    }
                }
            }
        }
        return true
    }

    // MARK: - 操作

    private func addToTimeline(_ item: MediaItem) {
        guard appState.currentProject != nil else { return }
        let service = TimelineService()
        do {
            try service.addClip(mediaItemId: item.id, project: &appState.currentProject!)
            try? appState.saveCurrentProject()
        } catch {
            VlogPackLog.error("Add to timeline failed: \(error)")
        }
    }

    private func deleteItem(_ item: MediaItem) {
        guard let root = appState.currentProjectRoot,
              appState.currentProject != nil else { return }
        do {
            try mediaService.removeMedia(
                itemId: item.id,
                projectRoot: root,
                project: &appState.currentProject!
            )
            try? appState.saveCurrentProject()
        } catch {
            VlogPackLog.error("Delete failed: \(error)")
        }
    }
}

// MARK: - 素材卡片

struct MediaItemCard: View {
    let item: MediaItem
    let projectRoot: URL

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 68)

                if item.type == .video, let thumbURL = thumbnailURL {
                    AsyncImage(url: thumbURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } placeholder: {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Image(systemName: iconForType)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // 视频时长标记
                if item.type == .video && item.duration > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatDuration(item.duration))
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.7))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(4)
                }
            }

            Text(item.originalFileName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 120)
    }

    private var thumbnailURL: URL? {
        let thumbURL = projectRoot
            .appendingPathComponent("cache/thumbnails")
            .appendingPathComponent("\(item.id).jpg")
        return FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL : nil
    }

    private var iconForType: String {
        switch item.type {
        case .video: return "film"
        case .image: return "photo"
        case .logo: return "star.square"
        }
    }

    private func formatDuration(_ d: Double) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}
