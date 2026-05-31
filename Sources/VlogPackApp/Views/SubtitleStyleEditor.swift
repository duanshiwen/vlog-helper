import SwiftUI
import VlogPackCore

/// 字幕样式编辑器
struct SubtitleStyleEditor: View {
    @Environment(AppState.self) private var appState
    @State private var templateService = TemplateService()
    @State private var isExpanded = false
    @State private var customTemplateName = ""

    private var style: Binding<SubtitleStyle> {
        Binding(
            get: { appState.currentProject?.subtitles?.style ?? SubtitleStyle() },
            set: { newValue in
                appState.currentProject?.subtitles?.style = newValue
                try? appState.saveCurrentProject()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "paintbrush")
                    Text("字幕样式")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // 模板
                    HStack {
                        Text("模板：").font(.caption)
                        ForEach(Array(templateService.builtinSubtitleTemplates.keys.sorted()), id: \.self) { name in
                            Button(name) {
                                if let tmpl = templateService.builtinSubtitleTemplates[name] {
                                    templateService.applySubtitleTemplate(tmpl, project: &appState.currentProject!)
                                    try? appState.saveCurrentProject()
                                }
                            }
                            .controlSize(.mini)
                            .buttonStyle(.bordered)
                        }
                    }

                    // 字体
                    HStack {
                        Text("字体").font(.caption).frame(width: 60, alignment: .trailing)
                        TextField("", text: style.fontFamily)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    // 字号
                    HStack {
                        Text("字号").font(.caption).frame(width: 60, alignment: .trailing)
                        Slider(value: style.fontSize, in: 24...120, step: 2)
                        Text("\(Int(style.fontSize.wrappedValue))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 30)
                    }

                    // 颜色
                    HStack {
                        Text("文字色").font(.caption).frame(width: 60, alignment: .trailing)
                        ColorField(hex: style.textColor)
                        Text("描边色").font(.caption)
                        ColorField(hex: style.outlineColor)
                    }

                    // 描边宽度
                    HStack {
                        Text("描边").font(.caption).frame(width: 60, alignment: .trailing)
                        Slider(value: style.outlineWidth, in: 0...10, step: 0.5)
                        Text(String(format: "%.1f", style.outlineWidth.wrappedValue))
                            .font(.caption.monospacedDigit())
                            .frame(width: 30)
                    }

                    // 位置
                    HStack {
                        Text("位置").font(.caption).frame(width: 60, alignment: .trailing)
                        Picker("", selection: style.position) {
                            Text("底部居中").tag(SubtitlePosition.bottomCenter)
                            Text("顶部居中").tag(SubtitlePosition.topCenter)
                            Text("居中").tag(SubtitlePosition.center)
                        }
                        .pickerStyle(.segmented)
                    }

                    // 底部边距
                    HStack {
                        Text("边距").font(.caption).frame(width: 60, alignment: .trailing)
                        Slider(value: style.marginBottom, in: 0...200, step: 5)
                        Text("\(Int(style.marginBottom.wrappedValue))px")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50)
                    }

                    // 保存为模板
                    HStack {
                        TextField("模板名称", text: $customTemplateName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        Button("保存为模板") {
                            guard !customTemplateName.isEmpty else { return }
                            try? templateService.saveSubtitleTemplate(
                                name: customTemplateName,
                                style: style.wrappedValue
                            )
                            customTemplateName = ""
                        }
                        .controlSize(.small)
                        .disabled(customTemplateName.isEmpty)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

/// 简单颜色输入框（Hex）
struct ColorField: View {
    @Binding var hex: String

    var body: some View {
        TextField("#FFFFFF", text: $hex)
            .textFieldStyle(.roundedBorder)
            .font(.caption.monospaced())
            .frame(width: 80)
            .onChange(of: hex) { _, newValue in
                // 确保以 # 开头
                if !newValue.hasPrefix("#") && !newValue.isEmpty {
                    hex = "#" + newValue
                }
            }
    }
}
