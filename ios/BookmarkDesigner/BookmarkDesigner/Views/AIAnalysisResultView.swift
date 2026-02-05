//
//  AIAnalysisResultView.swift
//  BookmarkDesigner
//
//  步骤2A: 显示AI解析结果（AI路径）
//

import SwiftUI
import os.log

// 生成步骤枚举
enum GenerationStep {
    case idle
    case generatingImage  // 文生图中
    case addingText       // 添加文字中
}

struct AIAnalysisResultView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var designState: DesignState
    @EnvironmentObject var networkManager: NetworkManager

    @State private var isGenerating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var generationStep: GenerationStep = .idle

    // 可编辑的AI参数
    @State private var editableDescription: String = ""

    // 文字设置
    @State private var textFont: String = "PingFang SC"
    @State private var textFontSize: Double = 16
    @State private var textColor: String = "#333333"
    @State private var isVerticalText: Bool = false
    @State private var textAlignment: String = "center"
    @State private var textPosition: String = "center"
    @State private var showingColorPicker = false
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
            backgroundImageSection

            // AI分析参数展示
            if let analysis = designState.analysisResult {
                aiAnalysisSection(analysis)
            }

            textInputSection
            generateButtonSection
        }
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                Text("AI解析完成")
                    .font(.system(size: 28, weight: .bold))
            }
            Text("AI已分析您的图片，您可以添加文字后生成书签")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }

    // AI分析参数展示区域
    private func aiAnalysisSection(_ analysis: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI分析结果")
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 12) {
                // 图片内容描述
                VStack(alignment: .leading, spacing: 8) {
                    Text("图片内容描述,可以修改描述自己想要的背景图像")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $editableDescription)
                        .font(.system(size: 14))
                        .frame(minHeight: 100)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                        )
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // 初始化可编辑参数
            editableDescription = analysis.description
        }
    }

    @ViewBuilder
    private var backgroundImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参考图片")
                .font(.system(size: 18, weight: .semibold))

            // 参考图片预览
            if !designState.referenceImages.isEmpty {
                VStack(spacing: 12) {
                    // 参考图片
                    Image(uiImage: designState.referenceImages[0])
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5)

                    // 参考图选项
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("文生图时使用参考图", isOn: $designState.useReferenceForGeneration)
                            .font(.system(size: 14))

                        // 生成的背景图预览
                        if let generatedImage = designState.generatedBackgroundImage {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("生成的背景图")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button("重新生成") {
                                        Task {
                                            await regenerateBackgroundImage()
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#667eea"))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                Image(uiImage: generatedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文字")
                .font(.system(size: 18, weight: .semibold))

            // 文字样式设置
            VStack(alignment: .leading, spacing: 10) {
//                Text("文字样式")
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(.secondary)

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
                        showingColorPicker = true
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
                                    .keyboardType(.numbersAndPunctuation)

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
                                    .keyboardType(.numbersAndPunctuation)

                                Text("px")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // 预设值快速填充
                            Button {
                                setPresetPosition(.top)
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
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 文字输入框（移到样式设置下方）
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

            // 可视化预览
            positionPreviewBox
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showingColorPicker) {
            TextColorPickerSheet(
                selectedColor: $textColor,
                onSave: {
                    showingColorPicker = false
                },
                onCancel: {
                    showingColorPicker = false
                }
            )
        }
    }

    private var generateButtonSection: some View {
        VStack(spacing: 12) {
            // 如果还没有生成背景图，显示"生成背景图"按钮
            if designState.generatedBackgroundImage == nil {
                Button {
                    print("🔵 [AIAnalysis] Generate background image button tapped")
                    Task {
                        await generateBackgroundImageOnly()
                    }
                } label: {
                    HStack {
                        if isGenerating && generationStep == .generatingImage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("正在生成背景图...")
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: "photo")
                            Text("生成背景图")
                        }
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: (isGenerating && generationStep == .generatingImage) ? [Color.gray, Color.gray] : [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: (isGenerating && generationStep == .generatingImage) ? Color.clear : Color(hex: "#667eea").opacity(0.3), radius: 10, y: 5)
                }
                .disabled(isGenerating && generationStep == .generatingImage)
            }

            // "生成书签"按钮（始终显示，但有背景图时才可用）
            Button {
                print("🔵 [AIAnalysis] Generate bookmark button tapped")
                Task {
                    await generateBookmarkWithText()
                }
            } label: {
                HStack {
                    if isGenerating && generationStep == .addingText {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("正在绘制文字...")
                            .font(.system(size: 16))
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
                        colors: (isGenerating && generationStep == .addingText) || (designState.generatedBackgroundImage == nil) ? [Color.gray, Color.gray] : [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: ((isGenerating && generationStep == .addingText) || designState.generatedBackgroundImage == nil) ? Color.clear : Color(hex: "#667eea").opacity(0.3), radius: 10, y: 5)
            }
            .disabled((isGenerating && generationStep == .addingText) || designState.generatedBackgroundImage == nil)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helper Methods

    private func generationStepText() -> String {
        switch generationStep {
        case .idle:
            return ""
        case .generatingImage:
            return "正在生成背景图..."
        case .addingText:
            return "正在绘制文字..."
        }
    }

    /// 仅生成背景图（不添加文字）
    private func generateBackgroundImageOnly() async {
        print("🔵 [AIAnalysis] generateBackgroundImageOnly called")

        await MainActor.run {
            isGenerating = true
            generationStep = .generatingImage
        }

        let moodValue = moodToBackendValue(designState.selectedMood)

        // 调用文生图API生成背景
        let imageResult = await networkManager.generateBackgroundImage(
            prompt: editableDescription.isEmpty ? designState.textToImagePrompt : editableDescription,
            mood: moodValue
        )

        await MainActor.run {
            isGenerating = false
            generationStep = .idle

            switch imageResult {
            case .success(let image):
                print("✅ [AIAnalysis] Background image generated successfully")
                designState.generatedBackgroundImage = image
            case .failure(let error):
                print("❌ [AIAnalysis] Background image generation failed: \(error.localizedDescription)")
                alertMessage = "背景图生成失败: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    /// 重新生成背景图
    private func regenerateBackgroundImage() async {
        print("🔄 [AIAnalysis] Regenerating background image")
        await generateBackgroundImageOnly()
    }

    /// 在已有背景图上添加文字并生成最终书签
    private func generateBookmarkWithText() async {
        print("🔵 [AIAnalysis] generateBookmarkWithText called")

        guard designState.generatedBackgroundImage != nil else {
            print("❌ [AIAnalysis] No background image")
            alertMessage = "请先生成背景图"
            showingAlert = true
            return
        }

        // 准备文字位置数据
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

        print("📝 [AIAnalysisResult] Text settings:")
        print("   - direction: \(direction)")
        print("   - alignment: \(textAlignment)")
        print("   - position: (\(positionX), \(positionY))")
        print("   - margins: top=\(position.top), bottom=\(position.bottom), left=\(position.left), right=\(position.right)")

        // 步骤: 在生成的背景图上绘制文字
        await MainActor.run {
            isGenerating = true
            generationStep = .addingText
        }

        // 调用网络请求生成书签
        let result = await networkManager.generateBookmark(designState: designState)

        await MainActor.run {
            isGenerating = false
            generationStep = .idle

            switch result {
            case .success(let data):
                print("✅ [AIAnalysis] Generation successful, saving data")
                designState.finalBookmarkImage = data.image
                designState.finalBookmarkPDF = data.pdf
                // 跳转到结果页面
                path.append("result")
                // 延迟清理临时数据（确保页面跳转完成）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.cleanupAfterGeneration()
                }
            case .failure(let error):
                print("❌ [AIAnalysis] Generation failed: \(error.localizedDescription)")
                designState.generationError = error.localizedDescription
                alertMessage = error.localizedDescription
                showingAlert = true
                // 失败时保留背景图，让用户可以重试
            }
        }
    }

    // 清理生成后的临时数据
    private func cleanupAfterGeneration() {
        print("🧹 [AIAnalysis] Cleaning up temporary data...")
        // 清理生成的背景图（已经用于生成最终书签，不再需要）
        designState.generatedBackgroundImage = nil
        print("✅ [AIAnalysis] Cleanup complete")
    }

    // MARK: - Helper Methods

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

        print("📍 [AIAnalysisResult] Text position calculation:")
        print("   - Input: X=\(positionX)px, Y=\(positionY)px")
        print("   - Bookmark size: \(bookmarkWidth)×\(bookmarkHeight)px")
        print("   - Text coordinates: (\(clampedX), \(clampedY))")
        print("   - Margins: top=\(topMargin), bottom=\(bottomMargin), left=\(leftMargin), right=\(rightMargin)")

        return (topMargin, bottomMargin, leftMargin, rightMargin)
    }

    private var positionPreviewBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置预览")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack {
                    // 背景框（模拟书签比例）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                        )

                    // 中心参考线（虚线）
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // 垂直中心线
                        path.move(to: CGPoint(x: width / 2, y: 0))
                        path.addLine(to: CGPoint(x: width / 2, y: height))

                        // 水平中心线
                        path.move(to: CGPoint(x: 0, y: height / 2))
                        path.addLine(to: CGPoint(x: width, y: height / 2))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color(uiColor: .systemGray3))

                    // 文字位置指示器
                    if let x = Double(positionX),
                       let y = Double(positionY) {
                        let boxWidth = geometry.size.width
                        let boxHeight = geometry.size.height

                        // 将书签坐标映射到预览框
                        let indicatorX = (x / Double(bookmarkWidth)) * boxWidth
                        let indicatorY = (y / Double(bookmarkHeight)) * boxHeight

                        // 限制指示器在预览框内
                        let clampedX = max(6, min(indicatorX, boxWidth - 6))
                        let clampedY = max(6, min(indicatorY, boxHeight - 6))

                        // 绘制指示器
                        Circle()
                            .fill(isVerticalText ? Color.orange : Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .position(x: clampedX, y: clampedY)
                    }

                    // 方向标签
                    VStack {
                        HStack {
                            Text("左")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("右")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack {
                            Text("上")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("下")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }
            }
            .frame(height: 160)
            .overlay(
                Text("书签尺寸: \(bookmarkWidth)×\(bookmarkHeight)px")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                , alignment: .topLeading
            )
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
    private func updatePrecisePositionFromQuick(_ position: String) {
        switch position {
        case "top":
            positionX = "354"  // 居中 X
            positionY = "200"  // 靠上 Y
        case "bottom":
            positionX = "354"  // 居中 X
            positionY = "1900" // 靠下 Y
        case "left":
            positionX = "100"  // 靠左 X
            positionY = "1063" // 居中 Y
        case "right":
            positionX = "600"  // 靠右 X
            positionY = "1063" // 居中 Y
        case "center":
            positionX = "354"  // 居中 X
            positionY = "1063" // 居中 Y
        default:
            positionX = "354"
            positionY = "1063"
        }
    }

    /// 设置预设位置
    enum PresetPosition {
        case top
        case center
        case bottom
        case left
        case right
    }

    private func setPresetPosition(_ preset: PresetPosition) {
        switch preset {
        case .top:
            positionX = "354"
            positionY = "200"
        case .center:
            positionX = "354"
            positionY = "1063"
        case .bottom:
            positionX = "354"
            positionY = "1900"
        case .left:
            positionX = "100"
            positionY = "1063"
        case .right:
            positionX = "600"
            positionY = "1063"
        }
    }

    private func moodToBackendValue(_ mood: MoodOption?) -> String {
        guard let mood = mood else {
            return "现代时尚"  // 默认值
        }

        switch mood {
        case .modern:
            return "现代时尚"
        case .vintage:
            return "优雅复古"
        case .minimal:
            return "专业简约"
        case .elegant:
            return "优雅复古"
        case .playful:
            return "活泼可爱"
        case .artistic:
            return "艺术文艺"
        }
    }
}

// 简单的色块组件
struct ColorSwatch: View {
    let color: DesignColor
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Color(hex: color.hex)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 2)

            Text(color.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(color.hex)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Text Color Picker Sheet

struct TextColorPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedColor: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private let presetColors = [
        "#333333", "#666666", "#999999", "#000000",
        "#667eea", "#764ba2", "#f093fb", "#4facfe",
        "#43e97b", "#fa709a", "#fee140", "#ff6b6b",
        "#4ecdc4", "#45b7d1", "#96ceb4", "#ff9a9e",
        "#a18cd1", "#fbc2eb", "#fad0c4", "#ffecd2",
        "#F5E6D3", "#E8F4F8", "#FFFFFF"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 当前颜色预览
                VStack(spacing: 12) {
                    Text("当前颜色")
                        .font(.system(size: 16, weight: .medium))

                    HStack(spacing: 16) {
                        Color(hex: selectedColor)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEX值")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(selectedColor.uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .monospaced()
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

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Color(hex: color)
                                    .frame(height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("文字颜色")
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

struct AIAnalysisResultView_Previews: PreviewProvider {
    static var previews: some View {
        @State var path: NavigationPath = .init()
        let designState = DesignState()

        // 创建模拟的配色方案（不直接赋值给@State）
        let previewScheme = ColorScheme(
            name: "AI推荐配色",
            colors: [
                DesignColor(hex: "#667eea", name: "紫蓝", role: .primary),
                DesignColor(hex: "#764ba2", name: "深紫", role: .primary),
                DesignColor(hex: "#f093fb", name: "粉紫", role: .secondary)
            ],
            mood: "modern"
        )

        return NavigationStack {
            AIAnalysisResultView(path: $path)
                .environmentObject(designState)
                .environmentObject(NetworkManager())
        }
    }
}
