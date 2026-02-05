//
//  RichTextEditorView.swift
//  BookmarkDesigner
//
//  富文本编辑器组件
//

import SwiftUI

struct RichTextEditorView: View {
    @Binding var richTextContent: RichTextContent
    @State private var blocks: [TextBlock] = []

    @State private var currentText = ""
    @State private var currentFontSize: FontSize = .medium
    @State private var currentAlignment: TextAlignment = .center
    @State private var currentDirection: TextDirection = .horizontal
    @State private var currentColor = "#333333"
    @State private var currentWeight = "normal"
    @State private var currentStyle = "normal"

    @State private var showingColorPicker = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 样式控制面板
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // 字号选择
                            Menu {
                                Button("小号") { currentFontSize = .small }
                                Button("中号") { currentFontSize = .medium }
                                Button("大号") { currentFontSize = .large }
                                Button("特大") { currentFontSize = .xlarge }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "textformat.size")
                                    Text(fontSizeDisplayText)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // 对齐方式
                            HStack(spacing: 4) {
                                Button {
                                    currentAlignment = .left
                                } label: {
                                    Image(systemName: "text.alignleft")
                                        .font(.system(size: 16))
                                        .foregroundStyle(currentAlignment == .left ? .white : .primary)
                                        .padding(8)
                                        .background(currentAlignment == .left ? Color(hex: "#667eea") : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                Button {
                                    currentAlignment = .center
                                } label: {
                                    Image(systemName: "text.aligncenter")
                                        .font(.system(size: 16))
                                        .foregroundStyle(currentAlignment == .center ? .white : .primary)
                                        .padding(8)
                                        .background(currentAlignment == .center ? Color(hex: "#667eea") : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                Button {
                                    currentAlignment = .right
                                } label: {
                                    Image(systemName: "text.alignright")
                                        .font(.system(size: 16))
                                        .foregroundStyle(currentAlignment == .right ? .white : .primary)
                                        .padding(8)
                                        .background(currentAlignment == .right ? Color(hex: "#667eea") : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // 文字方向
                            Button {
                                currentDirection = currentDirection == .horizontal ? .vertical : .horizontal
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: currentDirection == .horizontal ? "text.alignleft" : "textformat")
                                    Text(currentDirection == .horizontal ? "横排" : "竖排")
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // 颜色选择
                            Button {
                                showingColorPicker.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: currentColor))
                                        .frame(width: 20, height: 20)
                                    Text("颜色")
                                        .font(.system(size: 14))
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        // 预设颜色快速选择
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["#333333", "#667eea", "#f093fb", "#4facfe", "#43e97b", "#fa709a", "#fee140"], id: \.self) { color in
                                    Button {
                                        currentColor = color
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: currentColor == color ? 2 : 0)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 文本输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("输入文字")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $currentText)
                            .font(.system(size: 16))
                            .frame(minHeight: 80)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )

                        // 添加文本块按钮
                        Button {
                            addTextBlock()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("添加文本块")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(currentText.isEmpty ? Color.gray : Color(hex: "#667eea"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(currentText.isEmpty)
                    }
                    .padding(.horizontal, 20)

                    // 已添加的文本块列表
                    if !blocks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("已添加的文本块 (\(blocks.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(block.text)
                                            .font(.system(size: fontSizeValue(block.style.fontSize)))
                                            .foregroundStyle(Color(hex: block.style.color))
                                            .lineLimit(2)

                                        HStack(spacing: 8) {
                                            Text(alignmentDisplayText(block.style.alignment))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)

                                            Text(block.style.direction == .horizontal ? "横排" : "竖排")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)

                                            Text(fontSizeDisplayTextValue(block.style.fontSize))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        blocks.remove(at: index)
                                        updateRichTextContent()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding(12)
                                .background(Color(uiColor: .systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("富文本编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize blocks from existing richTextContent
                if !richTextContent.blocks.isEmpty && blocks.isEmpty {
                    blocks = richTextContent.blocks
                }
            }
            .onChange(of: blocks) { _, _ in
                updateRichTextContent()
            }
        }
    }

    // MARK: - Helper Methods

    private var fontSizeDisplayText: String {
        switch currentFontSize {
        case .small: return "小号"
        case .medium: return "中号"
        case .large: return "大号"
        case .xlarge: return "特大"
        }
    }

    private func fontSizeDisplayTextValue(_ size: FontSize) -> String {
        switch size {
        case .small: return "小号"
        case .medium: return "中号"
        case .large: return "大号"
        case .xlarge: return "特大"
        }
    }

    private func fontSizeValue(_ size: FontSize) -> CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        case .large: return 20
        case .xlarge: return 24
        }
    }

    private func alignmentDisplayText(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .left: return "左对齐"
        case .center: return "居中"
        case .right: return "右对齐"
        }
    }

    private func addTextBlock() {
        let style = TextStyle(
            fontSize: currentFontSize,
            fontWeight: currentWeight,
            fontStyle: currentStyle,
            color: currentColor,
            alignment: currentAlignment,
            direction: currentDirection
        )

        let block = TextBlock(text: currentText, style: style)
        blocks.append(block)

        // 重置输入
        currentText = ""
    }

    private func updateRichTextContent() {
        richTextContent = RichTextContent(blocks: blocks)
    }
}

#Preview {
    @State var content = RichTextContent(blocks: [])

    return RichTextEditorView(richTextContent: $content)
}
