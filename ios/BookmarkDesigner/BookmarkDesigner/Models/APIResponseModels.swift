//
//  APIResponseModels.swift
//  BookmarkDesigner
//
//  API响应和请求模型
//

import Foundation

// MARK: - Background Models

/// 背景类型
enum BackgroundType: String, Codable {
    case solid = "solid"
    case gradient = "gradient"
    case image = "image"
}

/// 渐变方向
enum GradientDirection: String, Codable {
    case horizontal = "horizontal"
    case vertical = "vertical"
    case diagonal = "diagonal"
    case radial = "radial"
}

/// 纯色背景
struct SolidBackground: Codable {
    let type: BackgroundType
    let color: String

    init(color: String) {
        self.type = .solid
        self.color = color
    }
}

/// 渐变背景
struct GradientBackground: Codable {
    let type: BackgroundType
    let direction: GradientDirection
    let colors: [String]
    let angle: Double

    init(direction: GradientDirection = .vertical, colors: [String], angle: Double = 90.0) {
        self.type = .gradient
        self.direction = direction
        self.colors = colors
        self.angle = angle
    }
}

/// 图片背景
struct ImageBackground: Codable {
    let type: BackgroundType
    let imagePath: String
    let opacity: Double
    let fitMode: String

    init(imagePath: String, opacity: Double = 1.0, fitMode: String = "cover") {
        self.type = .image
        self.imagePath = imagePath
        self.opacity = opacity
        self.fitMode = fitMode
    }
}

/// 背景设置
struct BackgroundSettings: Codable {
    let backgroundType: BackgroundType
    let solid: SolidBackground?
    let gradient: GradientBackground?
    let image: ImageBackground?

    init(solid: SolidBackground) {
        self.backgroundType = .solid
        self.solid = solid
        self.gradient = nil
        self.image = nil
    }

    init(gradient: GradientBackground) {
        self.backgroundType = .gradient
        self.solid = nil
        self.gradient = gradient
        self.image = nil
    }

    init(image: ImageBackground) {
        self.backgroundType = .image
        self.solid = nil
        self.gradient = nil
        self.image = image
    }
}

// MARK: - Text Position Models

/// 文本区域位置设置
struct TextPosition: Codable {
    let topMargin: Int
    let bottomMargin: Int
    let leftMargin: Int
    let rightMargin: Int
    let width: Int?
    let height: Int?
    let alignment: String        // left/center/right
    let direction: String        // horizontal/vertical

    init(
        topMargin: Int = 40,
        bottomMargin: Int = 40,
        leftMargin: Int = 40,
        rightMargin: Int = 40,
        width: Int? = nil,
        height: Int? = nil,
        alignment: String = "center",
        direction: String = "horizontal"
    ) {
        self.topMargin = topMargin
        self.bottomMargin = bottomMargin
        self.leftMargin = leftMargin
        self.rightMargin = rightMargin
        self.width = width
        self.height = height
        self.alignment = alignment
        self.direction = direction
    }
}

// MARK: - Rich Text Models

/// 文字方向
enum TextDirection: String, Codable, Equatable {
    case horizontal = "horizontal"
    case vertical = "vertical"
}

/// 对齐方式
enum TextAlignment: String, Codable, Equatable {
    case left = "left"
    case center = "center"
    case right = "right"
}

/// 字号大小
enum FontSize: String, Codable, Equatable {
    case small = "small"      // 14-16px
    case medium = "medium"    // 18-24px
    case large = "large"      // 28-36px
    case xlarge = "xlarge"    // 40-48px
}

/// 文本样式
struct TextStyle: Codable, Equatable {
    let fontSize: FontSize
    let fontWeight: String    // normal/bold
    let fontStyle: String     // normal/italic
    let color: String         // HEX color
    let alignment: TextAlignment
    let direction: TextDirection

    init(
        fontSize: FontSize = .medium,
        fontWeight: String = "normal",
        fontStyle: String = "normal",
        color: String = "#333333",
        alignment: TextAlignment = .center,
        direction: TextDirection = .horizontal
    ) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.color = color
        self.alignment = alignment
        self.direction = direction
    }
}

/// 文本块
struct TextBlock: Codable, Equatable {
    let text: String
    let style: TextStyle

    init(text: String, style: TextStyle = TextStyle()) {
        self.text = text
        self.style = style
    }
}

/// 富文本内容
struct RichTextContent: Codable {
    let blocks: [TextBlock]

    init(blocks: [TextBlock]) {
        self.blocks = blocks
    }
}

// MARK: - API请求模型

/// 图像分析请求
struct ImageAnalysisRequest: Codable {
    let images: [String] // base64编码的图片
}

/// 书签生成请求
struct BookmarkGenerationRequest: Codable {
    let designState: DesignStateData
    let materials: [String] // base64编码的用户素材
    let outputFormat: OutputFormat
    let dpi: Int

    enum OutputFormat: String, Codable {
        case png
        case pdf
    }
}

/// 设计状态数据（用于发送到后端）
struct DesignStateData: Codable {
    let analysisResult: ImageAnalysisResult?
    let selectedMood: String?
    let complexity: Double
    let formality: Double
    let selectedColorScheme: ColorSchemeData?
    let selectedLayout: LayoutData?
    let userText: String
}

/// 配色方案数据
struct ColorSchemeData: Codable {
    let name: String
    let colors: [DesignColor]
    let mood: String
}

/// 布局数据
struct LayoutData: Codable {
    let type: String
    let description: String
}

// MARK: - API响应模型

/// 图像分析响应
struct ImageAnalysisResponse: Codable {
    let success: Bool
    let data: ImageAnalysisResult?
    let error: String?
}

/// 书签生成响应
struct BookmarkGenerationResponse: Codable {
    let success: Bool
    let data: BookmarkGenerationResponseData?
    let error: String?
}

/// 书签生成数据
struct BookmarkGenerationResponseData: Codable {
    let imageUrl: String? // 如果返回URL
    let imageData: String? // base64编码的图片
    let pdfData: String? // base64编码的PDF
}

// MARK: - 错误模型

/// API错误
struct APIError: Error, LocalizedError {
    let message: String
    let statusCode: Int?

    var errorDescription: String? {
        return message
    }
}
