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
    @State private var relativeTime: Double = 0   // 相对于 inPoint 的时间
    @State private var timeObserverToken: Any?

    /// 当前播放的片段关键参数（用于检测裁剪变化）
    @State private var loadedClipKey: String = ""

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
                    // 播放/暂停
                    Button {
                        togglePlay()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)

                    // 进度条（relativeTime: 0 = inPoint，duration = outPoint - inPoint）
                    Slider(
                        value: $relativeTime,
                        in: 0...max(currentClip?.duration ?? 1, 0.1)
                    ) { editing in
                        if !editing, let clip = currentClip {
                            let absoluteTime = clip.inPoint + relativeTime
                            let time = CMTime(seconds: absoluteTime, preferredTimescale: 600)
                            player?.seek(to: time)
                        }
                    }

                    // 时间显示
                    Text(formatTime(relativeTime) + " / " + formatTime(currentClip?.duration ?? 0))
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
            reloadIfNeeded()
        }
        .onChange(of: clipCount) { _, _ in
            reloadIfNeeded()
        }
        .onChange(of: clipTrimKey) { _, _ in
            // 裁剪参数变化时强制刷新
            forceReload()
        }
        .onAppear {
            reloadIfNeeded()
        }
    }

    // MARK: - 当前片段

    private var currentClip: TimelineClip? {
        guard let project = appState.currentProject else { return nil }
        if let id = appState.selectedClipId,
           let clip = project.timeline.clips.first(where: { $0.id == id }) {
            return clip
        }
        return project.timeline.sortedClips.first
    }

    private var clipCount: Int {
        appState.currentProject?.timeline.clips.count ?? 0
    }

    /// 裁剪参数指纹，用于检测 in/out 变化
    private var clipTrimKey: String {
        guard let clip = currentClip else { return "" }
        return "\(clip.id)_\(clip.inPoint)_\(clip.outPoint)"
    }

    // MARK: - 加载

    private func reloadIfNeeded() {
        let key = clipTrimKey
        guard key != loadedClipKey else { return }
        forceReload()
    }

    private func forceReload() {
        guard let clip = currentClip,
              let project = appState.currentProject,
              let root = appState.currentProjectRoot,
              let media = project.mediaItems.first(where: { $0.id == clip.mediaItemId }) else {
            player = nil
            loadedClipKey = ""
            return
        }

        let wasPlaying = isPlaying
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let url = root.appendingPathComponent(media.projectRelativePath)
        let avPlayer = AVPlayer(url: url)

        // 跳到入点（用 toleranceBefore 精确定位）
        if clip.inPoint > 0 {
            let startTime = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
            avPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        self.player = avPlayer
        self.relativeTime = 0
        self.isPlaying = false
        self.loadedClipKey = clipTrimKey

        addPeriodicObserver()

        // 之前在播放则自动继续
        if wasPlaying {
            avPlayer.play()
            isPlaying = true
        }
    }

    // MARK: - 播放控制

    private func togglePlay() {
        guard let player, let clip = currentClip else { return }
        if isPlaying {
            player.pause()
        } else {
            // 如果已到出点附近，回到入点
            let absTime = clip.inPoint + relativeTime
            if absTime >= clip.outPoint - 0.3 {
                let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
                player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                relativeTime = 0
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func addPeriodicObserver() {
        guard let player else { return }
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                guard let clip = currentClip else { return }
                let abs = time.seconds
                // 计算相对于 inPoint 的时间
                let rel = max(0, abs - clip.inPoint)
                relativeTime = min(rel, clip.duration)

                // 超过出点自动暂停并回到入点
                if abs >= clip.outPoint - 0.05 {
                    player.pause()
                    isPlaying = false
                    let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
                    player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                    relativeTime = 0
                }
            }
        }
    }

    // MARK: - 格式化

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
