//
//  AdvancedSettingsView.swift
//  BookmarkDesigner
//
//  高级设置视图：背景、文本位置、边线装饰
//

import SwiftUI
import Foundation

struct AdvancedSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var designState: DesignState

    // 背景设置状态
    @State private var backgroundType: BackgroundMode = .none
    @State private var selectedBackgroundColor = "#F5F5DC"
    @State private var gradientDirection: GradientDirection = .vertical
    @State private var gradientColors: [String] = ["#F5F5DC", "#4A7C59"]
    @State private var showColorPicker = false

    // 文本位置设置状态
    @State private var customTextPosition = false
    @State private var topMargin: Double = 40
    @State private var bottomMargin: Double = 40
    @State private var leftMargin: Double = 40
    @State private var rightMargin: Double = 40

    // 预览状态
    @State private var previewText = "示例文字\n这是一段预览文本"
    @State private var previewFontSize: Double = 18
    @State private var previewTextColor = "#333333"

    enum BackgroundMode: String, CaseIterable {
        case none = "默认"
        case solid = "纯色"
        case gradient = "渐变"
        case image = "图片"

        var localizedName: String { rawValue }
    }

    // 为 GradientDirection 提供本地化名称
    var gradientDirectionOptions: [(direction: GradientDirection, localizedName: String)] {
        [
            (.vertical, "垂直"),
            (.horizontal, "水平"),
            (.diagonal, "对角"),
            (.radial, "径向")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 实时预览区域
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("实时预览")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                            Text("所见即所得")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        // 预览画布
                        GeometryReader { geometry in
                            ZStack {
                                // 背景
                                Group {
                                    if backgroundType == .solid {
                                        Color(hex: selectedBackgroundColor)
                                    } else if backgroundType == .gradient {
                                        LinearGradient(
                                            colors: gradientColors.map { Color(hex: $0) },
                                            startPoint: gradientStartPoint(direction: gradientDirection, size: geometry.size),
                                            endPoint: gradientEndPoint(direction: gradientDirection, size: geometry.size)
                                        )
                                    } else {
                                        Color(uiColor: .systemBackground)
                                    }
                                }
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                // 文本区域预览
                                if customTextPosition {
                                    // 显示边距指示器
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(
                                            width: geometry.size.width - leftMargin - rightMargin,
                                            height: 300 - topMargin - bottomMargin
                                        )
                                        .overlay(
                                            Rectangle()
                                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                        )
                                        .offset(x: (leftMargin - rightMargin) / 2, y: (topMargin - bottomMargin) / 2)

                                    // 边距标注
                                    ZStack {
                                        // 上边距标注
                                        VStack {
                                            HStack {
                                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                                Text("上: \(Int(topMargin))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.blue)
                                                Spacer()
                                            }
                                            .padding(.top, 5)

                                            Spacer()

                                            // 下边距标注
                                            HStack {
                                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                                Text("下: \(Int(bottomMargin))")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.blue)
                                                Spacer()
                                            }
                                            .padding(.bottom, 5)
                                        }
                                        .frame(height: 300)

                                        // 左边距标注
                                        VStack {
                                            Spacer()
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                                                    Text("左:\(Int(leftMargin))")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.blue)
                                                }
                                                Spacer()
                                            }
                                        }
                                        .frame(width: geometry.size.width)

                                        // 右边距标注
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                                                    Text("右:\(Int(rightMargin))")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                        }
                                        .frame(width: geometry.size.width)
                                    }
                                }

                                // 示例文字
                                VStack {
                                    Text(previewText)
                                        .font(.system(size: previewFontSize))
                                        .foregroundStyle(Color(hex: previewTextColor))
                                        .multilineTextAlignment(.center)
                                        .padding()
                                }
                                .frame(height: 300)
                            }
                        }
                        .frame(height: 300)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 预览文字和颜色设置
                        VStack(spacing: 12) {
                            TextField("预览文字", text: $previewText)
                                .textFieldStyle(.roundedBorder)

                            HStack {
                                Text("字号")
                                    .font(.system(size: 14))
                                Slider(value: $previewFontSize, in: 12...36, step: 1)
                                    .frame(maxWidth: 200)
                                Text("\(Int(previewFontSize))")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)

                                Spacer()

                                Color(hex: previewTextColor)
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )

                                TextField("", text: $previewTextColor)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .autocapitalization(.none)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 背景设置
                    VStack(alignment: .leading, spacing: 16) {
                        Text("背景设置")
                            .font(.system(size: 20, weight: .bold))

                        // 背景类型选择
                        Picker("背景类型", selection: $backgroundType) {
                            ForEach(BackgroundMode.allCases, id: \.self) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        // 纯色背景设置
                        if backgroundType == .solid {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("选择颜色")
                                    .font(.system(size: 16, weight: .medium))

                                HStack {
                                    Color(hex: selectedBackgroundColor)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray, lineWidth: 1)
                                        )

                                    TextField("颜色代码", text: $selectedBackgroundColor)
                                        .textFieldStyle(.roundedBorder)
                                        .autocapitalization(.none)
                                }

                                Text("使用HEX格式，如 #F5F5DC")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }

                        // 渐变背景设置
                        if backgroundType == .gradient {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("渐变方向")
                                    .font(.system(size: 16, weight: .medium))

                                Picker("方向", selection: $gradientDirection) {
                                    ForEach(gradientDirectionOptions, id: \.direction) { option in
                                        Text(option.localizedName).tag(option.direction)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("渐变颜色（至少2个）")
                                    .font(.system(size: 16, weight: .medium))

                                ForEach(0..<gradientColors.count, id: \.self) { index in
                                    HStack {
                                        Color(hex: gradientColors[index])
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray, lineWidth: 1)
                                            )

                                        TextField("颜色 \(index + 1)", text: $gradientColors[index])
                                            .textFieldStyle(.roundedBorder)
                                            .autocapitalization(.none)

                                        if gradientColors.count > 2 {
                                            Button(action: {
                                                gradientColors.remove(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                }

                                if gradientColors.count < 3 {
                                    Button(action: {
                                        gradientColors.append("#FFFFFF")
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("添加颜色")
                                        }
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: "#667eea"))
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        // 图片背景设置
                        if backgroundType == .image {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("图片背景")
                                    .font(.system(size: 16, weight: .medium))

                                Text("请先在上传内容步骤中添加背景图片")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 文本位置设置
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("文本位置")
                                .font(.system(size: 20, weight: .bold))

                            Spacer()

                            Toggle("自定义位置", isOn: $customTextPosition)
                        }

                        if customTextPosition {
                            VStack(spacing: 16) {
                                // 上边距
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("上边距")
                                            .font(.system(size: 14))
                                        Spacer()
                                        Text("\(Int(topMargin))px")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    Slider(value: $topMargin, in: 0...200, step: 5)
                                }

                                // 下边距
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("下边距")
                                            .font(.system(size: 14))
                                        Spacer()
                                        Text("\(Int(bottomMargin))px")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    Slider(value: $bottomMargin, in: 0...200, step: 5)
                                }

                                // 左边距
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("左边距")
                                            .font(.system(size: 14))
                                        Spacer()
                                        Text("\(Int(leftMargin))px")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    Slider(value: $leftMargin, in: 0...200, step: 5)
                                }

                                // 右边距
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("右边距")
                                            .font(.system(size: 14))
                                        Spacer()
                                        Text("\(Int(rightMargin))px")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    Slider(value: $rightMargin, in: 0...200, step: 5)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 边线装饰
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("边线装饰")
                                .font(.system(size: 20, weight: .bold))

                            Spacer()

                            Toggle("", isOn: $designState.showBorders)
                        }

                        Text("启用后将根据复杂度自动添加装饰性边线")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .navigationTitle("高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveSettings() {
        // 保存背景设置
        switch backgroundType {
        case .none:
            designState.backgroundSettings = nil

        case .solid:
            designState.backgroundSettings = BackgroundSettings(
                solid: SolidBackground(color: selectedBackgroundColor)
            )

        case .gradient:
            designState.backgroundSettings = BackgroundSettings(
                gradient: GradientBackground(
                    direction: gradientDirection,
                    colors: gradientColors
                )
            )

        case .image:
            // 图片背景需要用户先上传，这里暂时设为nil
            designState.backgroundSettings = nil
        }

        // 保存文本位置设置
        if customTextPosition {
            designState.textPosition = TextPosition(
                topMargin: Int(topMargin),
                bottomMargin: Int(bottomMargin),
                leftMargin: Int(leftMargin),
                rightMargin: Int(rightMargin)
            )
        } else {
            designState.textPosition = nil
        }

        // showBorders 已经直接绑定到 designState.showBorders
    }

    // MARK: - Helper Functions for Gradient Preview

    private func gradientStartPoint(direction: GradientDirection, size: CGSize) -> UnitPoint {
        switch direction {
        case .vertical:
            return .top
        case .horizontal:
            return .leading
        case .diagonal:
            return .topLeading
        case .radial:
            return .center
        }
    }

    private func gradientEndPoint(direction: GradientDirection, size: CGSize) -> UnitPoint {
        switch direction {
        case .vertical:
            return .bottom
        case .horizontal:
            return .trailing
        case .diagonal:
            return .bottomTrailing
        case .radial:
            return .center
        }
    }
}

struct AdvancedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedSettingsView()
            .environmentObject(DesignState())
    }
}
