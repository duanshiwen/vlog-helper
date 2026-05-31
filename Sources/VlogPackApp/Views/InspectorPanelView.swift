import SwiftUI
import VlogPackCore

/// 检查器标签
enum InspectorTab: String, CaseIterable {
    case trim = "裁剪"
    case subtitles = "字幕"
    case cover = "封面"
    case export = "导出"
    case project = "项目"
}

/// 检查器面板
struct InspectorPanelView: View {
    @State private var selectedTab: InspectorTab = .subtitles

    var body: some View {
        VStack(spacing: 0) {
            // 标签选择器
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // 内容（ScrollView 防止切换 Tab 时窗口变形）
            ScrollView {
                switch selectedTab {
                case .trim:
                    TrimEditorView()
                case .subtitles:
                    SubtitleEditorView()
                case .cover:
                    CoverEditorView()
                case .export:
                    ExportView()
                case .project:
                    ProjectInfoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
