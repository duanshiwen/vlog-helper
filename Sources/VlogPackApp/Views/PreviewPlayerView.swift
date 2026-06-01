import SwiftUI
import AVKit
import AppKit
import VlogPackCore

/// AppKit AVPlayerView 桥接
/// 注意：AVPlayerView 是 NSViewRepresentable，容易盖住 SwiftUI ZStack overlay。
/// 因此字幕 overlay 直接挂在 AVPlayerView 内部，确保永远位于视频上方。
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    let subtitleText: String

    func makeNSView(context: Context) -> SubtitlePlayerNSView {
        let view = SubtitlePlayerNSView()
        view.player = player
        // 关闭 AVPlayerView 原生控制条，避免与下方自定义控制栏形成“双进度条”
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.setSubtitle(subtitleText)
        return view
    }

    func updateNSView(_ nsView: SubtitlePlayerNSView, context: Context) {
        nsView.player = player
        nsView.setSubtitle(subtitleText)
    }
}

final class SubtitlePlayerNSView: AVPlayerView {
    private let subtitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.maximumNumberOfLines = 3
        label.lineBreakMode = .byWordWrapping
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        label.layer?.cornerRadius = 8
        label.layer?.masksToBounds = true
        label.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            return shadow
        }()
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubtitleLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubtitleLabel()
    }

    private func setupSubtitleLabel() {
        addSubview(subtitleLabel, positioned: .above, relativeTo: nil)
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.86),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    func setSubtitle(_ text: String) {
        subtitleLabel.stringValue = text
        subtitleLabel.isHidden = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 视频预览播放器（支持字幕叠加）
struct PreviewPlayerView: View {
    @Environment(AppState.self) private var appState
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var relativeTime: Double = 0
    @State private var timeObserverToken: Any?
    @State private var loadedClipKey: String = ""
    /// 当前可见的字幕文本
    @State private var currentSubtitleText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 播放区
            ZStack {
                Color.black

                if let player {
                    PlayerView(player: player, subtitleText: currentSubtitleText)
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

                    Slider(
                        value: $relativeTime,
                        in: 0...max(currentClip?.duration ?? 1, 0.1)
                    ) { editing in
                        if !editing, let clip = currentClip {
                            let absoluteTime = clip.inPoint + relativeTime
                            let time = CMTime(seconds: absoluteTime, preferredTimescale: 600)
                            player?.seek(to: time)
                            currentSubtitleText = findCurrentSubtitle(
                                timelineTime: timelineTime(for: clip, relativeTime: relativeTime)
                            )
                        }
                    }

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
           let clip = project.timeline.clip(byId: id) {
            return clip
        }
        return project.timeline.videoTrack?.sortedClips.first
    }

    private var clipCount: Int {
        appState.currentProject?.timeline.videoTrack?.clips.count ?? 0
    }

    private var clipTrimKey: String {
        guard let clip = currentClip else { return "" }
        return "\(clip.id)_\(clip.inPoint)_\(clip.outPoint)"
    }

    // MARK: - 字幕

    /// 根据时间线时间查找匹配的字幕。
    /// 字幕转写基于“剪辑后的连续时间线音频”，因此这里不能用源视频绝对时间。
    private func findCurrentSubtitle(timelineTime: Double) -> String {
        guard let project = appState.currentProject else { return "" }

        // 优先使用多轨字幕 clip
        if let subtitleTrack = project.timeline.subtitleTrack {
            for clip in subtitleTrack.sortedClips {
                if timelineTime >= clip.startTime && timelineTime < clip.endTime {
                    return clip.subtitleText ?? ""
                }
            }
        }

        // 兼容：旧项目或尚未同步到字幕轨时，直接使用 SubtitleDocument
        if let segments = project.subtitles?.segments {
            for segment in segments {
                if timelineTime >= segment.start && timelineTime < segment.end {
                    return segment.text
                }
            }
        }

        return ""
    }

    /// 当前 clip 内相对时间 → 全局时间线时间
    private func timelineTime(for clip: TimelineClip, relativeTime: Double) -> Double {
        clip.startTime + relativeTime
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
            currentSubtitleText = ""
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

        if clip.inPoint > 0 {
            let startTime = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
            avPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        self.player = avPlayer
        self.relativeTime = 0
        self.isPlaying = false
        self.loadedClipKey = clipTrimKey
        self.currentSubtitleText = ""

        addPeriodicObserver()

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
                let rel = max(0, abs - clip.inPoint)
                relativeTime = min(rel, clip.duration)

                // 更新字幕：字幕轨使用的是时间线时间，而不是源视频绝对时间
                currentSubtitleText = findCurrentSubtitle(timelineTime: timelineTime(for: clip, relativeTime: rel))

                // 超过出点自动暂停
                if abs >= clip.outPoint - 0.05 {
                    player.pause()
                    isPlaying = false
                    let start = CMTime(seconds: clip.inPoint, preferredTimescale: 600)
                    player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                    relativeTime = 0
                    currentSubtitleText = ""
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
