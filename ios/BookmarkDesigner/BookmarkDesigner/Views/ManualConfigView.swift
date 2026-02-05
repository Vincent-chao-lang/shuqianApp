//
//  ManualConfigView.swift
//  BookmarkDesigner
//
//  步骤2B: 手动配置（手动路径）
//

import SwiftUI
import os.log

struct ManualConfigView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var designState: DesignState
    @EnvironmentObject var networkManager: NetworkManager

    @State private var isGenerating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // 背景设置
    @State private var backgroundType: BackgroundType = .image
    @State private var solidColor: Color = .white
    @State private var gradientStartColor: Color = Color(hex: "#667eea")
    @State private var gradientEndColor: Color = Color(hex: "#764ba2")
    @State private var showingSolidColorPicker = false
    @State private var showingGradientStartColorPicker = false
    @State private var showingGradientEndColorPicker = false

    // 文字设置
    @State private var textFont: String = "PingFang SC"
    @State private var textFontSize: Double = 16
    @State private var textColor: String = "#333333"
    @State private var isVerticalText: Bool = false
    @State private var textAlignment: String = "center"
    @State private var textPosition: String = "center"
    @State private var showingTextColorPicker = false
    @State private var positionMode: String = "quick"  // quick 或 precise
    @State private var positionX: String = "354"
    @State private var positionY: String = "1063"

    // 书签尺寸（300 DPI）
    private let bookmarkWidth: Int = 708   // 60mm at 300 DPI
    private let bookmarkHeight: Int = 2126  // 180mm at 300 DPI

    // 计算文字宽度
    private var calculatedTextWidth: Int {
        if isVerticalText {
            // 竖排文字：根据实际内容计算宽度
            let textCount = designState.userText.count
            let maxCharsPerColumn = 10
            let maxColumns = 3
            let displayChars = min(textCount, maxColumns * maxCharsPerColumn)

            let columns = (displayChars + maxCharsPerColumn - 1) / maxCharsPerColumn

            // 每列宽度 = 字号 * 1.2 (字符宽度)
            let charWidth = Int(textFontSize * 1.2)
            let actualWidth = columns * charWidth

            return actualWidth
        } else {
            // 水平文字：书签宽度的80%
            return Int(Double(bookmarkWidth) * 0.8)
        }
    }

    // 估算文字占用宽度（基于字符数）
    private var estimatedTextWidth: String {
        let textCount = designState.userText.count
        if textCount == 0 {
            return "0"
        }

        if isVerticalText {
            // 竖排模式：最多10个字一列，最多3列（最多30个字）
            let maxCharsPerColumn = 10
            let maxColumns = 3
            let maxTotalChars = maxCharsPerColumn * maxColumns

            let displayChars = min(textCount, maxTotalChars)
            let columns = (displayChars + maxCharsPerColumn - 1) / maxCharsPerColumn

            if textCount > maxTotalChars {
                return "\(columns)列 × \(maxCharsPerColumn)字 (超出\(textCount - maxTotalChars)字)"
            } else {
                let charsInLastColumn = displayChars % maxCharsPerColumn
                if charsInLastColumn == 0 {
                    return "\(columns)列 × \(maxCharsPerColumn)字"
                } else {
                    return "\(columns)列 (末列\(charsInLastColumn)字)"
                }
            }
        } else {
            // 水平模式：显示估算的像素宽度
            let charWidth = max(Int(textFontSize * 1.2), 10) // 每个字符大约占用的像素，最小10px
            let totalWidth = textCount * charWidth
            let availableWidth = calculatedTextWidth
            let percentage = availableWidth > 0 ? min(100, (totalWidth * 100) / availableWidth) : 0
            return "~\(totalWidth)px (\(percentage)%)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 进度指示器
                ProgressBar(currentStep: 2, totalSteps: 2)

                contentView
            }

            Spacer().frame(height: 20)
        }
        .navigationBarBackButtonHidden()
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Content Views

    private var contentView: some View {
        VStack(spacing: 24) {
            titleSection
            backgroundSection
            textSection
            generateButtonSection
        }
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("手动配置")
                .font(.system(size: 28, weight: .bold))
            Text("自定义背景和添加文字")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 背景设置区域

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("背景设置")
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 12) {
                // 背景类型选择
                Picker("背景类型", selection: $backgroundType) {
                    Text("图片").tag(BackgroundType.image)
                    Text("纯色").tag(BackgroundType.solid)
                    Text("渐变").tag(BackgroundType.gradient)
                }
                .pickerStyle(.segmented)

                // 根据类型显示不同选项
                switch backgroundType {
                case .image:
                    imageBackgroundView
                case .solid:
                    solidColorBackgroundView
                case .gradient:
                    gradientBackgroundView
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
    }

    // 图片背景
    private var imageBackgroundView: some View {
        VStack(spacing: 12) {
            if !designState.referenceImages.isEmpty {
                Image(uiImage: designState.referenceImages[0])
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 5)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("请先上传图片")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 纯色背景
    private var solidColorBackgroundView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("选择颜色")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingSolidColorPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(solidColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )

                        Text("选择颜色")
                            .font(.system(size: 14))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // 预览
            Rectangle()
                .fill(solidColor)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Text("预览")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                )
        }
    }

    // 渐变色背景
    private var gradientBackgroundView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 起始颜色
                Button {
                    showingGradientStartColorPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(gradientStartColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )

                        Text("起始")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                Spacer()

                // 结束颜色
                Button {
                    showingGradientEndColorPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(gradientEndColor)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )

                        Text("结束")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 预览
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [gradientStartColor, gradientEndColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Text("预览")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                )
        }
    }

    // MARK: - 文字设置区域

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文字")
                .font(.system(size: 18, weight: .semibold))

            // 文字输入框
            TextField("输入书签上的文字...", text: $designState.userText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .padding(.vertical, 8)

            // 文字宽度信息显示
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if isVerticalText {
                    Text("实际宽度: \(calculatedTextWidth)px")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("最大宽度: \(calculatedTextWidth)px")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !designState.userText.isEmpty {
                    // 检查是否超出竖排限制
                    let exceedsLimit = isVerticalText && designState.userText.count > 30

                    HStack(spacing: 4) {
                        Circle()
                            .fill(exceedsLimit ? Color.red : (isVerticalText ? Color.orange : Color.blue))
                            .frame(width: 6, height: 6)

                        Text("预估: \(estimatedTextWidth)")
                            .font(.system(size: 11))
                            .foregroundStyle(exceedsLimit ? .red : .secondary)

                        if exceedsLimit {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            // 文字样式设置
            VStack(alignment: .leading, spacing: 10) {
                // 第一行：字体和字号
                HStack(spacing: 16) {
                    // 字体选择
                    HStack(spacing: 8) {
                        Text("字体")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $textFont) {
                            Text("PingFang SC").tag("PingFang SC")
                            Text("STHeiti").tag("STHeiti")
                            Text("Kaiti").tag("Kaiti")
                            Text("Songti").tag("Songti")
                            Text("Helvetica").tag("Helvetica")
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()

                    // 字号
                    HStack(spacing: 6) {
                        Text("字号")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Button("-") {
                                if textFontSize > 12 {
                                    textFontSize -= 2
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color(uiColor: .systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text("\(Int(textFontSize))")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#667eea"))
                                .frame(width: 28)

                            Button("+") {
                                if textFontSize < 48 {
                                    textFontSize += 2
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color(uiColor: .systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // 第二行：颜色、对齐、方向
                HStack(spacing: 12) {
                    // 颜色选择
                    Button {
                        showingTextColorPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: textColor))
                                .frame(width: 20, height: 20)

                            Text("颜色")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Spacer()

                    // 对齐方式
                    HStack(spacing: 4) {
                        ForEach(["left", "center", "right"], id: \.self) { align in
                            Button {
                                textAlignment = align
                            } label: {
                                Image(systemName: alignmentIcon(align))
                                    .font(.system(size: 12))
                                    .frame(width: 32, height: 28)
                                    .background(textAlignment == align ? Color(hex: "#667eea") : Color(uiColor: .systemGray5))
                                    .foregroundStyle(textAlignment == align ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    // 竖排/横排切换
                    Button {
                        isVerticalText.toggle()
                    } label: {
                        Text(isVerticalText ? "竖" : "横")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 32, height: 28)
                            .background(isVerticalText ? Color(hex: "#667eea") : Color(uiColor: .systemGray5))
                            .foregroundStyle(isVerticalText ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // 第三行：位置设置（支持精确数值）
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("位置")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        // 切换按钮：快速选择/精确设置
                        Picker("", selection: $positionMode) {
                            Text("快速").tag("quick")
                            Text("精确").tag("precise")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)

                        Spacer()
                    }

                    // 可视化预览
                    positionPreviewBox

                    if positionMode == "quick" {
                        // 快速选择模式：预设位置
                        HStack(spacing: 6) {
                            ForEach(["top", "bottom", "left", "right", "center"], id: \.self) { position in
                                Button {
                                    textPosition = position
                                    // 同步到精确数值
                                    updatePrecisePositionFromQuick(position)
                                } label: {
                                    Text(positionName(position))
                                        .font(.system(size: 11))
                                        .frame(width: 44, height: 32)
                                        .background(textPosition == position ? Color(hex: "#667eea") : Color(uiColor: .systemGray5))
                                        .foregroundStyle(textPosition == position ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    } else {
                        // 精确设置模式：输入X和Y坐标
                        VStack(spacing: 12) {
                            // X和Y坐标输入
                            HStack(spacing: 16) {
                                // X坐标
                                HStack(spacing: 8) {
                                    Text("X")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)

                                    TextField("354", text: $positionX)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                        .keyboardType(.numberPad)

                                    Text("px")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                // Y坐标
                                HStack(spacing: 8) {
                                    Text("Y")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)

                                    TextField("1063", text: $positionY)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 70)
                                        .keyboardType(.numberPad)

                                    Text("px")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // 预设值快速填充
                                Button {
                                    setPresetPosition(.topLeading)
                                } label: {
                                    Text("左上")
                                        .font(.system(size: 10))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color(uiColor: .systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                Button {
                                    setPresetPosition(.center)
                                } label: {
                                    Text("居中")
                                        .font(.system(size: 10))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color(uiColor: .systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showingTextColorPicker) {
            TextColorPickerSheet(
                selectedColor: $textColor,
                onSave: {
                    showingTextColorPicker = false
                },
                onCancel: {
                    showingTextColorPicker = false
                }
            )
        }
        .sheet(isPresented: $showingSolidColorPicker) {
            SolidColorPickerSheet(
                selectedColor: $solidColor,
                onSave: {
                    showingSolidColorPicker = false
                },
                onCancel: {
                    showingSolidColorPicker = false
                }
            )
        }
        .sheet(isPresented: $showingGradientStartColorPicker) {
            SolidColorPickerSheet(
                selectedColor: $gradientStartColor,
                onSave: {
                    showingGradientStartColorPicker = false
                },
                onCancel: {
                    showingGradientStartColorPicker = false
                }
            )
        }
        .sheet(isPresented: $showingGradientEndColorPicker) {
            SolidColorPickerSheet(
                selectedColor: $gradientEndColor,
                onSave: {
                    showingGradientEndColorPicker = false
                },
                onCancel: {
                    showingGradientEndColorPicker = false
                }
            )
        }
    }

    private var generateButtonSection: some View {
        Button {
            Task {
                await generateBookmark()
            }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "sparkles")
                    Text("生成书签")
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: isGenerating ? [Color.gray, Color.gray] : [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: isGenerating ? Color.clear : Color(hex: "#667eea").opacity(0.3), radius: 10, y: 5)
        }
        .padding(.horizontal, 24)
        .disabled(isGenerating)
    }

    // MARK: - Helper Methods

    // 位置预览框
    private var positionPreviewBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("预览")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // 书签背景
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .systemGray4), lineWidth: 2)
                        )

                    // 网格线（帮助定位）
                    Path { path in
                        // 水平中线
                        path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.5))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.5))

                        // 垂直中线
                        path.move(to: CGPoint(x: geometry.size.width * 0.5, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height))
                    }
                    .stroke(Color(uiColor: .systemGray5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // 文字位置指示器（按比例缩放）
                    if let x = Double(positionX),
                       let y = Double(positionY) {
                        // 实际书签尺寸
                        let actualBookmarkWidth: Double = 708
                        let actualBookmarkHeight: Double = 2126

                        // 计算缩放比例（从实际尺寸映射到预览框尺寸）
                        let scaleX = geometry.size.width / actualBookmarkWidth
                        let scaleY = geometry.size.height / actualBookmarkHeight

                        // 计算预览框中的位置
                        let previewX = x * scaleX
                        let previewY = y * scaleY

                        Circle()
                            .fill(Color(hex: "#667eea"))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .position(x: previewX, y: previewY)
                    }

                    // 位置标签
                    VStack {
                        HStack {
                            Text("X: 0")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("X: 708")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack {
                            Text("Y: 0")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Y: 2126")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }
            }
            .frame(height: 160)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func generateBookmark() async {
        print("🔵 [ManualConfig] generateBookmark called")

        // 验证背景设置
        if backgroundType == .image && designState.referenceImages.isEmpty {
            print("❌ [ManualConfig] No reference images for image background")
            alertMessage = "请先上传背景图片"
            showingAlert = true
            return
        }

        guard !designState.userText.isEmpty else {
            print("❌ [ManualConfig] No text input")
            alertMessage = "请输入文字内容"
            showingAlert = true
            return
        }

        print("✅ [ManualConfig] Starting generation...")
        isGenerating = true
        designState.isGenerating = true

        // 准备背景设置数据
        if backgroundType == .solid {
            let solidBg = SolidBackground(color: solidColor.toHex() ?? "#FFFFFF")
            designState.backgroundSettings = BackgroundSettings(solid: solidBg)
        } else if backgroundType == .gradient {
            let gradientBg = GradientBackground(
                direction: .vertical,
                colors: [gradientStartColor.toHex() ?? "#667eea", gradientEndColor.toHex() ?? "#764ba2"],
                angle: 90.0
            )
            designState.backgroundSettings = BackgroundSettings(gradient: gradientBg)
        }

        // 准备文字位置数据（将位置转换为边距）
        let position = calculateTextMargins()

        // 确定文字方向
        let direction = isVerticalText ? "vertical" : "horizontal"

        designState.textPosition = TextPosition(
            topMargin: position.top,
            bottomMargin: position.bottom,
            leftMargin: position.left,
            rightMargin: position.right,
            alignment: textAlignment,
            direction: direction
        )

        print("📝 [ManualConfig] Text settings:")
        print("   - direction: \(direction)")
        print("   - alignment: \(textAlignment)")
        print("   - font: \(textFont), size: \(Int(textFontSize))")
        print("   - color: \(textColor)")

        // 调用网络请求生成书签
        let result = await networkManager.generateBookmark(designState: designState)

        await MainActor.run {
            isGenerating = false
            designState.isGenerating = false

            switch result {
            case .success(let data):
                print("✅ [ManualConfig] Generation successful, saving data")
                designState.finalBookmarkImage = data.image
                designState.finalBookmarkPDF = data.pdf
                path.append("result")
            case .failure(let error):
                print("❌ [ManualConfig] Generation failed: \(error.localizedDescription)")
                designState.generationError = error.localizedDescription
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }

    private func alignmentIcon(_ alignment: String) -> String {
        switch alignment {
        case "left": return "text.alignleft"
        case "center": return "text.aligncenter"
        case "right": return "text.alignright"
        default: return "text.aligncenter"
        }
    }

    private func positionName(_ position: String) -> String {
        switch position {
        case "top": return "上"
        case "bottom": return "下"
        case "left": return "左"
        case "right": return "右"
        case "center": return "中"
        default: return "中"
        }
    }

    /// 从快速选择的位置更新精确数值
    /// 基于书签实际尺寸（708×2126px）设置预设位置
    private func updatePrecisePositionFromQuick(_ position: String) {
        switch position {
        case "top":
            positionX = "354"  // 水平居中
            positionY = "100"  // 距离顶部100px
        case "bottom":
            positionX = "354"  // 水平居中
            positionY = "2000" // 距离顶部2000px（接近底部）
        case "left":
            positionX = "100"  // 距离左边100px
            positionY = "1063" // 垂直居中
        case "right":
            positionX = "608"  // 距离左边608px（接近右边）
            positionY = "1063" // 垂直居中
        case "center":
            positionX = "354"  // 水平居中
            positionY = "1063" // 垂直居中
        default:
            positionX = "354"
            positionY = "1063"
        }
    }

    /// 设置预设位置（使用像素值）
    private func setPresetPosition(_ unitPoint: UnitPoint) {
        let bookmarkWidth: Double = 708
        let bookmarkHeight: Double = 2126

        positionX = String(format: "%.0f", unitPoint.x * bookmarkWidth)
        positionY = String(format: "%.0f", unitPoint.y * bookmarkHeight)
    }

    /// 计算文字边距（从位置设置转换为topMargin等）
    /// 直接使用像素值定位：
    /// - X值表示距离左边的像素距离（0-书签宽度）
    /// - Y值表示距离顶部的像素距离（0-书签高度）
    ///
    /// 例如：Y=100 表示文字距离顶部100px
    ///
    /// 注意：书签实际尺寸为 60mm × 180mm
    /// - 预览模式（72 DPI）：约 170px × 510px
    /// - 最终输出（300 DPI）：约 708px × 2126px
    private func calculateTextMargins() -> (top: Int, bottom: Int, left: Int, right: Int) {
        guard let x = Double(positionX),
              let y = Double(positionY) else {
            return (40, 40, 40, 40) // 默认值：居中
        }

        // 书签实际尺寸（60mm × 180mm 在 300 DPI 下）
        let bookmarkWidth: Int = 708   // 60mm at 300 DPI
        let bookmarkHeight: Int = 2126  // 180mm at 300 DPI

        // 直接使用输入值作为像素坐标
        let textX = Int(x)
        let textY = Int(y)

        // 限制坐标在书签范围内
        let clampedX = max(0, min(textX, bookmarkWidth))
        let clampedY = max(0, min(textY, bookmarkHeight))

        // 最小边距为20px，确保文字不会贴边
        let minMargin: Int = 20

        // 左边距：文字的X坐标（但不能小于最小边距）
        let leftMargin = max(clampedX, minMargin)

        // 右边距：书签宽度 - 文字X坐标（但不能小于最小边距）
        let rightMargin = max(bookmarkWidth - clampedX, minMargin)

        // 上边距：文字的Y坐标（但不能小于最小边距）
        let topMargin = max(clampedY, minMargin)

        // 下边距：书签高度 - 文字Y坐标（但不能小于最小边距）
        let bottomMargin = max(bookmarkHeight - clampedY, minMargin)

        print("📍 [ManualConfig] Text position calculation:")
        print("   - Input: X=\(positionX)px, Y=\(positionY)px")
        print("   - Bookmark size: \(bookmarkWidth)×\(bookmarkHeight)px")
        print("   - Text coordinates: (\(clampedX), \(clampedY))")
        print("   - Margins: top=\(topMargin), bottom=\(bottomMargin), left=\(leftMargin), right=\(rightMargin)")

        return (topMargin, bottomMargin, leftMargin, rightMargin)
    }
}

// MARK: - Solid Color Picker Sheet

struct SolidColorPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedColor: Color
    let onSave: () -> Void
    let onCancel: () -> Void

    private let presetColors: [Color] = [
        .white, .black, .red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan,
        Color(hex: "#667eea"), Color(hex: "#764ba2"), Color(hex: "#f093fb"),
        Color(hex: "#4facfe"), Color(hex: "#43e97b"), Color(hex: "#fa709a"),
        Color(hex: "#fee140"), Color(hex: "#ff6b6b"), Color(hex: "#4ecdc4"),
        Color(hex: "#45b7d1"), Color(hex: "#96ceb4"), Color(hex: "#ff9a9e"),
        Color(hex: "#a18cd1"), Color(hex: "#fbc2eb"), Color(hex: "#fad0c4"),
        Color(hex: "#F5E6D3"), Color(hex: "#E8F4F8"), Color(uiColor: .systemGray6)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 当前颜色预览
                VStack(spacing: 12) {
                    Text("当前颜色")
                        .font(.system(size: 16, weight: .medium))

                    HStack(spacing: 16) {
                        selectedColor
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Solid Color")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 预设颜色
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择颜色")
                        .font(.system(size: 16, weight: .medium))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(0..<presetColors.count, id: \.self) { index in
                            Button {
                                selectedColor = presetColors[index]
                            } label: {
                                presetColors[index]
                                    .frame(height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColor == presetColors[index] ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("选择颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ManualConfigView_Previews: PreviewProvider {
    static var previews: some View {
        @State var path: NavigationPath = .init()
        let designState = DesignState()

        return NavigationStack {
            ManualConfigView(path: $path)
                .environmentObject(designState)
                .environmentObject(NetworkManager())
        }
    }
}
