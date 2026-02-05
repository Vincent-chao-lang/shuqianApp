//
//  DesignState.swift
//  BookmarkDesigner
//
//  全局设计状态管理，在各个步骤间共享数据
//

import SwiftUI
import Combine

/// 全局设计状态类
final class DesignState: ObservableObject {
    // MARK: - Published Properties

    /// 当前步骤（1-5）
    @Published var currentStep: Int = 1

    // MARK: - 步骤1: 参考图

    /// 用户上传的参考图片数据
    @Published var referenceImages: [UIImage] = []

    /// AI分析结果
    @Published var analysisResult: ImageAnalysisResult?

    /// 是否正在分析
    @Published var isAnalyzing: Bool = false

    /// 分析错误信息
    @Published var analysisError: String?

    /// 文生图描述（使用AI解析结果）
    @Published var textToImagePrompt: String = ""

    /// 文生图生成的背景图片
    @Published var generatedBackgroundImage: UIImage?

    /// 是否在文生图时使用参考图
    @Published var useReferenceForGeneration: Bool = true

    // MARK: - 步骤2: 风格确认

    /// 选中的氛围
    @Published var selectedMood: MoodOption?

    /// 复杂度 (1-10)
    @Published var complexity: Double = 5

    /// 正式度 (1-10)
    @Published var formality: Double = 5

    // MARK: - 步骤3: 配色

    /// 可选配色方案
    @Published var availableColorSchemes: [ColorScheme] = ColorScheme.exampleSchemes

    /// 选中的配色方案
    @Published var selectedColorScheme: ColorScheme?

    // MARK: - 步骤4: 布局

    /// 可选布局方案
    @Published var availableLayouts: [LayoutOption] = LayoutOption.exampleLayouts

    /// 选中的布局
    @Published var selectedLayout: LayoutOption?

    // MARK: - 步骤5: 内容素材

    /// 用户上传的照片素材
    @Published var userPhotos: [UIImage] = []

    /// 用户输入的文字
    @Published var userText: String = ""

    /// 富文本内容（可选，用于样式化文字）
    @Published var richTextContent: RichTextContent?

    // MARK: - 高级设置

    /// 背景设置（可选）
    @Published var backgroundSettings: BackgroundSettings?

    /// 文本区域位置设置（可选）
    @Published var textPosition: TextPosition?

    /// 是否显示边线装饰（默认false）
    @Published var showBorders: Bool = false

    /// 是否正在生成
    @Published var isGenerating: Bool = false

    /// 生成错误信息
    @Published var generationError: String?

    /// 最终生成的书签图片
    @Published var finalBookmarkImage: UIImage?

    /// 最终生成的书签PDF数据
    @Published var finalBookmarkPDF: Data?

    // MARK: - Computed Properties

    /// 是否可以进入下一步骤
    var canProceedToNextStep: Bool {
        switch currentStep {
        case 1:
            return !referenceImages.isEmpty && analysisResult != nil
        case 2:
            return selectedMood != nil
        case 3:
            return selectedColorScheme != nil
        case 4:
            return !userText.isEmpty || !userPhotos.isEmpty
        default:
            return false
        }
    }

    /// 复杂度描述
    var complexityDescription: String {
        switch Int(complexity) {
        case 1...3: return "简约"
        case 4...6: return "适中"
        case 7...10: return "丰富"
        default: return "适中"
        }
    }

    /// 正式度描述
    var formalityDescription: String {
        switch Int(formality) {
        case 1...3: return "休闲"
        case 4...6: return "平衡"
        case 7...10: return "正式"
        default: return "平衡"
        }
    }

    // MARK: - Methods

    /// 重置所有状态
    func reset() {
        currentStep = 1
        referenceImages = []
        analysisResult = nil
        isAnalyzing = false
        analysisError = nil

        selectedMood = nil
        complexity = 5
        formality = 5

        availableColorSchemes = ColorScheme.exampleSchemes
        selectedColorScheme = nil

        availableLayouts = LayoutOption.exampleLayouts
        selectedLayout = nil

        userPhotos = []
        userText = ""
        isGenerating = false
        generationError = nil

        finalBookmarkImage = nil
        finalBookmarkPDF = nil
    }

    /// 进入下一步
    func goToNextStep() {
        if currentStep < 2 {  // 简化为2步流程
            currentStep += 1
        }
    }

    /// 返回上一步
    func goToPreviousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }

    /// 从AI分析结果创建配色方案
    func createColorSchemeFromAnalysis(_ analysis: ImageAnalysisResult) -> ColorScheme? {
        let suggestedColors = analysis.suggestedColors
        guard !suggestedColors.isEmpty else { return nil }

        // 从AI建议的颜色创建配色方案
        return ColorScheme(
            name: "AI推荐配色",
            colors: suggestedColors,
            mood: analysis.style_attributes.mood.rawValue
        )
    }
}

// MARK: - 辅助类型

/// 氛围选项
enum MoodOption: String, CaseIterable, Identifiable {
    case modern = "现代"
    case vintage = "复古"
    case minimal = "简约"
    case elegant = "优雅"
    case playful = "活泼"
    case artistic = "艺术"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .modern: return "building.2"
        case .vintage: return "clock"
        case .minimal: return "circle"
        case .elegant: return "sparkles"
        case .playful: return "star"
        case .artistic: return "paintbrush"
        }
    }
}

/// 颜色
struct DesignColor: Codable, Hashable {
    let hex: String
    let name: String
    let role: ColorRole

    enum ColorRole: String, Codable {
        case primary = "主色"
        case secondary = "辅色"
        case accent = "点缀"
        case background = "背景"
    }
}

/// 配色方案
struct ColorScheme: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let colors: [DesignColor]
    let mood: String

    static let exampleSchemes: [ColorScheme] = [
        ColorScheme(
            name: "温暖米色系",
            colors: [
                DesignColor(hex: "#F5E6D3", name: "米色", role: .background),
                DesignColor(hex: "#8B7355", name: "棕褐", role: .primary),
                DesignColor(hex: "#D4A574", name: "金棕", role: .secondary),
                DesignColor(hex: "#FFFFFF", name: "白色", role: .accent)
            ],
            mood: "vintage"
        ),
        ColorScheme(
            name: "清冷蓝绿系",
            colors: [
                DesignColor(hex: "#E8F4F8", name: "淡蓝", role: .background),
                DesignColor(hex: "#2E86AB", name: "海蓝", role: .primary),
                DesignColor(hex: "#A23B72", name: "紫红", role: .accent),
                DesignColor(hex: "#F18F01", name: "橙黄", role: .secondary)
            ],
            mood: "modern"
        ),
        ColorScheme(
            name: "自然绿色系",
            colors: [
                DesignColor(hex: "#F0F5E9", name: "浅绿", role: .background),
                DesignColor(hex: "#4A7C59", name: "橄榄绿", role: .primary),
                DesignColor(hex: "#E4A452", name: "土黄", role: .accent),
                DesignColor(hex: "#8B4513", name: "深棕", role: .secondary)
            ],
            mood: "minimal"
        )
    ]
}

/// 布局类型
enum LayoutType: String, CaseIterable, Identifiable {
    case horizontal = "左右分栏"
    case vertical = "上下分栏"
    case centered = "居中对称"
    case mosaic = "拼贴"
    case fullBleed = "全图覆盖"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .horizontal: return "rectangle.split.2x1"
        case .vertical: return "rectangle.split.1x2"
        case .centered: return "rectangle.center.inset.filled"
        case .mosaic: return "square.grid.3x3"
        case .fullBleed: return "rectangle.fill"
        }
    }
}

/// 布局选项
struct LayoutOption: Identifiable, Equatable {
    let id = UUID()
    let type: LayoutType
    let description: String
    let previewImageName: String // SF Symbol或资源名称

    static let exampleLayouts: [LayoutOption] = [
        LayoutOption(
            type: .horizontal,
            description: "图片在左，文字在右",
            previewImageName: "rectangle.split.2x1"
        ),
        LayoutOption(
            type: .vertical,
            description: "图片在上，文字在下",
            previewImageName: "rectangle.split.1x2"
        ),
        LayoutOption(
            type: .centered,
            description: "内容居中对齐",
            previewImageName: "rectangle.center.inset.filled"
        )
    ]
}

/// AI图像分析结果（匹配后端响应）
struct ImageAnalysisResult: Codable {
    let layout: LayoutInfo
    let colors: ColorSchemeInfo
    let typography: TypographyInfo
    let style_attributes: StyleAttributesInfo
    let decorative_elements: DecorativeElementsInfo
    let suggestions: [String]
    let preview: String?  // AI对图片的描述
    let raw_analysis: String?

    // 为了兼容现有代码，添加计算属性
    var mood: String {
        return style_attributes.mood.rawValue
    }

    var complexity: Int {
        return style_attributes.complexity
    }

    var formality: Int {
        return 5 // 默认值
    }

    var description: String {
        // 优先使用 preview，其次 raw_analysis，最后使用默认值
        return preview ?? raw_analysis ?? "AI分析完成"
    }

    var suggestedColors: [DesignColor] {
        var result: [DesignColor] = []
        result.append(contentsOf: self.colors.primary.map { DesignColor(hex: $0.hex, name: $0.name, role: .primary) })
        result.append(contentsOf: self.colors.secondary.map { DesignColor(hex: $0.hex, name: $0.name, role: .secondary) })
        result.append(contentsOf: self.colors.accent.map { DesignColor(hex: $0.hex, name: $0.name, role: .accent) })
        return result
    }

    var layoutType: String {
        return layout.type.rawValue
    }

    var keyElements: [String] {
        return style_attributes.keywords
    }
}

// MARK: - 后端响应模型

struct LayoutInfo: Codable {
    let type: LayoutTypeEnum
    let confidence: Double
    let description: String
}

enum LayoutTypeEnum: String, Codable {
    case leftRight = "left-right"
    case topBottom = "top-bottom"
    case centerFocused = "center-focused"
    case mosaicGrid = "mosaic-grid"
    case fullBleedImage = "full-bleed-image"
}

struct DesignColorInfo: Codable {
    let hex: String
    let name: String
}

struct ColorSchemeInfo: Codable {
    let primary: [DesignColorInfo]
    let secondary: [DesignColorInfo]
    let accent: [DesignColorInfo]
    let neutral: [DesignColorInfo]
    let palette_name: String
    let mood: String
    let harmony: String
}

struct TypographyInfo: Codable {
    let primary_font: String
    let body_font: String
    let font_pairs: [String]
    let text_color: String
}

struct StyleAttributesInfo: Codable {
    let keywords: [String]
    let mood: MoodTypeEnum
    let complexity: Int
    let aesthetic_tags: [String]
}

enum MoodTypeEnum: String, Codable {
    case warm = "温暖治愈"
    case fresh = "清新自然"
    case professional = "专业简约"
    case lively = "活泼可爱"
    case elegant = "优雅复古"
    case modern = "现代时尚"
    case artistic = "艺术文艺"
}

struct DecorativeElementsInfo: Codable {
    let has_border: Bool
    let has_pattern: Bool
    let has_icon: Bool
    let suggested_elements: [String]
}
