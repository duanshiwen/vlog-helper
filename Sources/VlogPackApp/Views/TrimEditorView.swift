import SwiftUI
import VlogPackCore

/// 片段裁剪编辑器
struct TrimEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var timelineService = TimelineService()
    @State private var inPointText: String = ""
    @State private var outPointText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let clip = selectedClip, let media = mediaItem(for: clip) {
                // 片段信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                        Text(media.originalFileName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text("素材时长: \(formatTime(media.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)

                Divider()

                // 裁剪控件
                VStack(alignment: .leading, spacing: 10) {
                    Text("裁剪范围")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)

                    // 入点
                    HStack {
                        Text("入点")
                            .font(.callout)
                            .frame(width: 40, alignment: .trailing)
                        TextField("0:00.0", text: $inPointText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospacedDigit())
                            .frame(width: 90)
                            .onSubmit { applyInPoint() }

                        Stepper("", value: Binding(
                            get: { clip.inPoint },
                            set: { newValue in
                                try? timelineService.setInPoint(
                                    clipId: clip.id,
                                    inPoint: max(0, newValue),
                                    project: &appState.currentProject!
                                )
                                refreshTexts()
                                try? appState.saveCurrentProject()
                            }
                        ), in: 0...clip.outPoint, step: 0.5)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 10)

                    // 出点
                    HStack {
                        Text("出点")
                            .font(.callout)
                            .frame(width: 40, alignment: .trailing)
                        TextField("0:00.0", text: $outPointText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospacedDigit())
                            .frame(width: 90)
                            .onSubmit { applyOutPoint() }

                        Stepper("", value: Binding(
                            get: { clip.outPoint },
                            set: { newValue in
                                try? timelineService.setOutPoint(
                                    clipId: clip.id,
                                    outPoint: min(media.duration, newValue),
                                    project: &appState.currentProject!
                                )
                                refreshTexts()
                                try? appState.saveCurrentProject()
                            }
                        ), in: clip.inPoint...media.duration, step: 0.5)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 10)

                    // 裁剪后时长
                    HStack {
                        Text("片段时长")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(clip.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)

                    // 进度条可视化
                    TrimRangeBar(
                        inPoint: clip.inPoint,
                        outPoint: clip.outPoint,
                        totalDuration: media.duration
                    )
                    .padding(.horizontal, 10)

                    // 错误信息
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                    }

                    Divider()

                    // 快捷操作
                    VStack(spacing: 6) {
                        HStack {
                            Button("设为当前位置") {
                                // TODO: 预览播放器时间同步后实现
                            }
                            .controlSize(.small)
                            .disabled(true)

                            Button("重置为完整") {
                                resetToFull()
                            }
                            .controlSize(.small)
                        }

                        HStack {
                            Button("裁掉前 5 秒") {
                                trimFromStart(seconds: 5)
                            }
                            .controlSize(.small)

                            Button("裁掉后 5 秒") {
                                trimFromEnd(seconds: 5)
                            }
                            .controlSize(.small)
                        }

                        HStack {
                            Button("裁掉前 10 秒") {
                                trimFromStart(seconds: 10)
                            }
                            .controlSize(.small)

                            Button("裁掉后 10 秒") {
                                trimFromEnd(seconds: 10)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            } else {
                // 未选中片段
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "scissors")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("在时间线中选择一个片段\n即可在此编辑裁剪范围")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: appState.selectedClipId) {
            refreshTexts()
        }
        .onAppear {
            refreshTexts()
        }
    }

    // MARK: - Selected Clip

    private var selectedClip: TimelineClip? {
        guard let id = appState.selectedClipId else { return nil }
        return appState.currentProject?.timeline.clips.first(where: { $0.id == id })
    }

    private func mediaItem(for clip: TimelineClip) -> MediaItem? {
        appState.currentProject?.mediaItems.first { $0.id == clip.mediaItemId }
    }

    // MARK: - Actions

    private func refreshTexts() {
        guard let clip = selectedClip else {
            inPointText = ""
            outPointText = ""
            return
        }
        inPointText = formatTime(clip.inPoint)
        outPointText = formatTime(clip.outPoint)
        errorMessage = nil
    }

    private func applyInPoint() {
        guard let clip = selectedClip,
              let project = appState.currentProject,
              let seconds = parseTime(inPointText) else {
            errorMessage = "时间格式错误，请用 m:ss.s 格式"
            return
        }
        do {
            try timelineService.setInPoint(clipId: clip.id, inPoint: seconds, project: &appState.currentProject!)
            try appState.saveCurrentProject()
            errorMessage = nil
        } catch {
            errorMessage = "入点无效：不能超过出点"
            refreshTexts()
        }
    }

    private func applyOutPoint() {
        guard let clip = selectedClip,
              let media = mediaItem(for: clip),
              let seconds = parseTime(outPointText) else {
            errorMessage = "时间格式错误，请用 m:ss.s 格式"
            return
        }
        do {
            try timelineService.setOutPoint(clipId: clip.id, outPoint: min(seconds, media.duration), project: &appState.currentProject!)
            try appState.saveCurrentProject()
            errorMessage = nil
        } catch {
            errorMessage = "出点无效：不能小于入点"
            refreshTexts()
        }
    }

    private func resetToFull() {
        guard let clip = selectedClip, let media = mediaItem(for: clip) else { return }
        try? timelineService.setInPoint(clipId: clip.id, inPoint: 0, project: &appState.currentProject!)
        try? timelineService.setOutPoint(clipId: clip.id, outPoint: media.duration, project: &appState.currentProject!)
        refreshTexts()
        try? appState.saveCurrentProject()
    }

    private func trimFromStart(seconds: Double) {
        guard let clip = selectedClip else { return }
        let newIn = min(clip.inPoint + seconds, clip.outPoint - 0.1)
        try? timelineService.setInPoint(clipId: clip.id, inPoint: newIn, project: &appState.currentProject!)
        refreshTexts()
        try? appState.saveCurrentProject()
    }

    private func trimFromEnd(seconds: Double) {
        guard let clip = selectedClip else { return }
        let newOut = max(clip.outPoint - seconds, clip.inPoint + 0.1)
        try? timelineService.setOutPoint(clipId: clip.id, outPoint: newOut, project: &appState.currentProject!)
        refreshTexts()
        try? appState.saveCurrentProject()
    }

    // MARK: - Time Formatting

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }

    private func parseTime(_ str: String) -> Double? {
        let parts = str.split(separator: ":")
        if parts.count == 2,
           let m = Double(parts[0]),
           let s = Double(parts[1]) {
            return m * 60 + s
        }
        if let direct = Double(str) {
            return direct
        }
        return nil
    }
}

// MARK: - 裁剪范围可视化条

struct TrimRangeBar: View {
    let inPoint: Double
    let outPoint: Double
    let totalDuration: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let startX = totalDuration > 0 ? w * (inPoint / totalDuration) : 0
            let endX = totalDuration > 0 ? w * (outPoint / totalDuration) : w

            ZStack(alignment: .leading) {
                // 灰色背景
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 20)

                // 裁剪后的范围（蓝色高亮）
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(width: max(0, endX - startX), height: 20)
                    .offset(x: startX)

                // 入点标记
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: 20)
                    .offset(x: startX)

                // 出点标记
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 20)
                    .offset(x: endX - 2)
            }
        }
        .frame(height: 20)
    }
}
