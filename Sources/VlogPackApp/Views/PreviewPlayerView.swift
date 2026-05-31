import SwiftUI
import AVKit
import AppKit
import VlogPackCore

/// AppKit AVPlayerView 桥接
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

/// 视频预览播放器
struct PreviewPlayerView: View {
    @Environment(AppState.self) private var appState
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var currentPlayingClipId: String?
    @State private var timeObserverToken: Any?

    var body: some View {
        VStack(spacing: 0) {
            // 播放区
            ZStack {
                Color.black

                if let player {
                    PlayerView(player: player)
                        .onAppear {
                            addPeriodicObserver()
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("选择时间线片段预览")
                            .font(.callout)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 控制栏
            if player != nil {
                Divider()
                HStack(spacing: 12) {
                    Button {
                        togglePlay()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)

                    Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                        if !editing {
                            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                            player?.seek(to: time)
                        }
                    }

                    Text(formatTime(currentTime) + " / " + formatTime(duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 100)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .onChange(of: appState.selectedClipId) { _, _ in
            loadClipForSelected()
        }
        .onChange(of: clipCount) { _, _ in
            // 片段增减时也刷新
            loadClipForSelected()
        }
        .onAppear {
            loadClipForSelected()
        }
    }

    // MARK: - Helpers

    /// 当前时间线片段数量（用于监听变化）
    private var clipCount: Int {
        appState.currentProject?.timeline.clips.count ?? 0
    }

    /// 获取当前要播放的片段和素材
    private var currentClipAndMedia: (TimelineClip, MediaItem)? {
        guard let project = appState.currentProject,
              let root = appState.currentProjectRoot else { return nil }

        // 优先播放选中的片段
        if let selectedId = appState.selectedClipId,
           let clip = project.timeline.clips.first(where: { $0.id == selectedId }),
           let media = project.mediaItems.first(where: { $0.id == clip.mediaItemId }) {
            return (clip, media)
        }

        // 否则播放第一个片段
        if let firstClip = project.timeline.sortedClips.first,
           let media = project.mediaItems.first(where: { $0.id == firstClip.mediaItemId }) {
            return (firstClip, media)
        }

        return nil
    }

    private func loadClipForSelected() {
        guard let (clip, media) = currentClipAndMedia,
              let root = appState.currentProjectRoot else {
            player = nil
            currentPlayingClipId = nil
            return
        }

        // 同一个片段不需要重新加载
        if clip.id == currentPlayingClipId { return }

        let wasPlaying = isPlaying
        player?.pause()

        let url = root.appendingPathComponent(media.projectRelativePath)
        let avPlayer = AVPlayer(url: url)

        // 跳到入点
        if clip.inPoint > 0 {
            let startTime = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
            avPlayer.seek(to: startTime)
        }

        self.player = avPlayer
        self.duration = clip.duration
        self.currentTime = clip.inPoint
        self.isPlaying = false
        self.currentPlayingClipId = clip.id

        addPeriodicObserver()

        // 之前在播放则自动播放
        if wasPlaying {
            avPlayer.play()
            isPlaying = true
        }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            // 如果播放到了出点附近，回到入点
            let clip = currentClipAndMedia?.0
            if let clip, currentTime >= clip.outPoint - 0.2 {
                let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
                player.seek(to: start)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func addPeriodicObserver() {
        guard let player else { return }
        // 移除旧的观察者
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                currentTime = time.seconds
                // 播放到出点时自动暂停
                if let clip = currentClipAndMedia?.0,
                   time.seconds >= clip.outPoint - 0.1 {
                    player.pause()
                    isPlaying = false
                }
            }
        }
    }

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
