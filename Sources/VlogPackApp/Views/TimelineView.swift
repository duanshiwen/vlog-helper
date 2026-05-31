import SwiftUI
import VlogPackCore

/// 时间线视图
struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var timelineService = TimelineService()
    @State private var selectedClipId: String?

    var body: some View {
        VStack(spacing: 0) {
            // 时间线标题栏
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundStyle(.secondary)
                Text("时间线")
                    .font(.headline)
                Spacer()
                Text(formatDuration(totalDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !clips.isEmpty {
                    Text("\(clips.count) 个片段")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // 时间线内容
            if clips.isEmpty {
                emptyTimelineView
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(clips) { clip in
                            TimelineClipView(
                                clip: clip,
                                mediaItem: mediaItem(for: clip),
                                isSelected: clip.id == selectedClipId
                            )
                            .onTapGesture {
                                selectedClipId = clip.id
                            }
                            .contextMenu {
                                Button("裁剪开头…") { }
                                Button("裁剪结尾…") { }
                                Divider()
                                Button("移除", role: .destructive) {
                                    removeClip(clip)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyTimelineView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("从素材库拖入或右键添加素材")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var clips: [TimelineClip] {
        appState.currentProject?.timeline.sortedClips ?? []
    }

    private var totalDuration: Double {
        appState.currentProject?.timeline.totalDuration ?? 0
    }

    private func mediaItem(for clip: TimelineClip) -> MediaItem? {
        appState.currentProject?.mediaItems.first { $0.id == clip.mediaItemId }
    }

    private func removeClip(_ clip: TimelineClip) {
        guard appState.currentProject != nil else { return }
        timelineService.removeClip(clipId: clip.id, project: &appState.currentProject!)
        try? appState.saveCurrentProject()
    }

    private func formatDuration(_ d: Double) -> String {
        let h = Int(d) / 3600
        let m = (Int(d) % 3600) / 60
        let s = Int(d) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 时间线片段视图

struct TimelineClipView: View {
    let clip: TimelineClip
    let mediaItem: MediaItem?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color(nsColor: .separatorColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .frame(width: clipWidth, height: 48)
                .overlay(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(mediaItem?.originalFileName ?? "Unknown")
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 6)
                }

            Text("\(formatTime(clip.inPoint)) — \(formatTime(clip.outPoint))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var clipWidth: CGFloat {
        let duration = clip.duration
        // 每秒 10 像素，最少 80，最多 300
        return max(80, min(300, CGFloat(duration) * 10))
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}
