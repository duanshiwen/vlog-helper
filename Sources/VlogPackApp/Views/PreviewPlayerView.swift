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
        .onChange(of: selectedClipMediaItem) { _, _ in
            loadClip()
        }
    }

    // MARK: - Helpers

    private var selectedClipMediaItem: MediaItem? {
        // 如果有时间线片段，播放第一个
        guard let project = appState.currentProject,
              let firstClip = project.timeline.sortedClips.first,
              let root = appState.currentProjectRoot else { return nil }
        let mediaItem = project.mediaItems.first { $0.id == firstClip.mediaItemId }
        return mediaItem
    }

    private func loadClip() {
        guard let item = selectedClipMediaItem,
              let root = appState.currentProjectRoot else {
            player = nil
            return
        }

        let url = root.appendingPathComponent(item.projectRelativePath)
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        self.duration = item.duration
        self.currentTime = 0
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func addPeriodicObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                currentTime = time.seconds
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
