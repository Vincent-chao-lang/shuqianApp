//
//  NetworkManager.swift
//  BookmarkDesigner
//
//  网络管理器，处理所有API请求
//

import Foundation
import UIKit
import os.log

@MainActor
final class NetworkManager: ObservableObject {
    // MARK: - Configuration

    // TODO: 替换为实际的后端URL
    private let baseURL = "http://localhost:8000/api"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.qiupc.BookmarkDesigner", category: "Network")

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)

        // 调试：打印baseURL
        let baseURLValue = self.baseURL
        NSLog("🌐 [NetworkManager] Initialized with baseURL: \(baseURLValue)")
        logger.log("NetworkManager initialized with baseURL: \(baseURLValue)")
    }

    // MARK: - Public Methods

    /// 分析参考图片
    func analyzeImages(_ images: [UIImage]) async -> Result<ImageAnalysisResult, APIError> {
        NSLog("📸 [NetworkManager] analyzeImages called with \(images.count) images")
        logger.log("analyzeImages called with \(images.count) images")

        do {
            // 准备multipart/form-data请求
            let urlString = baseURL + "/analyze-reference"
            NSLog("🔗 [NetworkManager] Full URL: \(urlString)")

            guard let url = URL(string: urlString) else {
                NSLog("❌ [NetworkManager] Invalid URL")
                return .failure(APIError(message: "无效的URL", statusCode: nil))
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            // 创建boundary
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // 构建multipart body
            var body = Data()

            for (index, image) in images.enumerated() {
                let imageName = "images"  // 所有图片使用相同的字段名
                let filename = "image\(index).jpg"
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    return .failure(APIError(message: "图片处理失败: \(filename)", statusCode: nil))
                }

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(imageName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // 调试：打印请求体的一部分
            if let bodyString = String(data: body, encoding: .utf8) {
                let preview = String(bodyString.prefix(500))
                NSLog("📤 [NetworkManager] Request body preview:\n\(preview)")
            }

            NSLog("📤 [NetworkManager] Sending request...")
            NSLog("   - URL: \(url.absoluteString)")
            NSLog("   - Method: POST")
            NSLog("   - Body size: \(body.count) bytes")
            NSLog("   - Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "nil")")

            // 发送请求
            let (data, response) = try await session.data(for: request)

            NSLog("📥 [NetworkManager] Response received")
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ [NetworkManager] Invalid response type")
                return .failure(APIError(message: "无效的响应", statusCode: nil))
            }

            NSLog("📊 [NetworkManager] HTTP Status: \(httpResponse.statusCode)")
            guard 200...299 ~= httpResponse.statusCode else {
                // 尝试解析错误响应
                if let errorString = String(data: data, encoding: .utf8) {
                    NSLog("❌ [NetworkManager] Error response: \(errorString)")
                    return .failure(APIError(message: "后端错误(\(httpResponse.statusCode)): \(errorString)", statusCode: httpResponse.statusCode))
                }
                NSLog("❌ [NetworkManager] HTTP error without details")
                return .failure(APIError(message: "HTTP错误: \(httpResponse.statusCode)", statusCode: httpResponse.statusCode))
            }

            // 解析响应
            NSLog("✅ [NetworkManager] Parsing response...")
            let decoder = JSONDecoder()
            let result = try decoder.decode(ImageAnalysisResult.self, from: data)

            NSLog("✅ [NetworkManager] Analysis successful!")
            return .success(result)

        } catch let error as APIError {
            NSLog("❌ [NetworkManager] APIError: \(error.message)")
            return .failure(error)
        } catch {
            NSLog("❌ [NetworkManager] Exception: \(error.localizedDescription)")
            return .failure(APIError(message: "分析失败: \(error.localizedDescription)", statusCode: nil))
        }
    }

    /// 生成书签
    func generateBookmark(designState: DesignState) async -> Result<BookmarkGenerationData, APIError> {
        do {
            // 准备multipart/form-data请求
            guard let url = URL(string: baseURL + "/generate-final") else {
                return .failure(APIError(message: "无效的URL", statusCode: nil))
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            // 创建boundary
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // 构建multipart body
            var body = Data()

            // 从DesignState获取值并转换为后端期望的格式
            // mood: 从selectedMood转换为后端的中文枚举值
            let moodValue = moodToBackendValue(designState.selectedMood)

            // layout: 从selectedLayout转换为后端的枚举值
            let layoutValue = layoutToBackendValue(designState.selectedLayout)

            // colors: 从selectedColorScheme获取颜色HEX值
            let colorsArray = designState.selectedColorScheme?.colors.map { $0.hex } ?? []

            let parameters: [String: Any] = [
                "mood": moodValue,
                "complexity": Int(designState.complexity),
                "colors": colorsArray,
                "layout": layoutValue,
                "user_text": designState.userText
            ]

            print("📤 [Network] Sending generate-final request:")
            print("   - mood: \(moodValue)")
            print("   - layout: \(layoutValue)")
            print("   - colors: \(colorsArray)")
            print("   - complexity: \(designState.complexity)")
            print("   - user_text: \(designState.userText)")
            print("   - use reference for generation: \(designState.useReferenceForGeneration)")

            // 如果有富文本内容，转换为JSON字符串
            var richTextString: String? = nil
            if let richText = designState.richTextContent {
                if let jsonData = try? JSONEncoder().encode(richText),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    richTextString = jsonString
                    print("   - rich_text: \(richText.blocks.count) blocks")
                }
            }

            // 如果有背景设置，转换为JSON字符串
            var backgroundString: String? = nil
            if let background = designState.backgroundSettings {
                if let jsonData = try? JSONEncoder().encode(background),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    backgroundString = jsonString
                    print("   - background: \(background.backgroundType.rawValue)")
                }
            }

            // 如果有文本位置设置，转换为JSON字符串
            var textPositionString: String? = nil
            if let textPos = designState.textPosition {
                if let jsonData = try? JSONEncoder().encode(textPos),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    textPositionString = jsonString
                    print("   - text_position: provided")
                }
            }

            print("   - show_borders: \(designState.showBorders)")

            // 处理背景图片：使用文生图生成的背景图
            var backgroundImageData: Data? = nil

            if let generatedImage = designState.generatedBackgroundImage {
                // 使用已生成的背景图
                backgroundImageData = generatedImage.jpegData(compressionQuality: 0.8)
                print("🎨 [Network] Using generated background image")
            } else {
                print("⚠️ [Network] No generated background image available")
            }

            for (key, value) in parameters {
                if let arrayValue = value as? [String] {
                    // 数组：每个元素作为单独的同名字段发送
                    for item in arrayValue {
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                        body.append(item.data(using: .utf8)!)
                        body.append("\r\n".data(using: .utf8)!)
                    }
                } else {
                    // 单值：直接添加
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                    body.append("\(value)".data(using: .utf8)!)
                    body.append("\r\n".data(using: .utf8)!)
                }
            }

            // 添加背景图片（参考图片或文生图）
            if let photoData = backgroundImageData {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"user_photo\"; filename=\"background.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(photoData)
                body.append("\r\n".data(using: .utf8)!)
                print("   - user_photo: sent (generated background image)")
            } else {
                print("   - user_photo: not sent (no image data)")
            }

            // 添加富文本（如果有）
            if let richTextString = richTextString {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"rich_text\"\r\n\r\n".data(using: .utf8)!)
                body.append(richTextString.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }

            // 添加背景设置（如果有）
            if let backgroundString = backgroundString {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"background\"\r\n\r\n".data(using: .utf8)!)
                body.append(backgroundString.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }

            // 添加文本位置设置（如果有）
            if let textPositionString = textPositionString {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"text_position\"\r\n\r\n".data(using: .utf8)!)
                body.append(textPositionString.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }

            // 添加边线开关
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"show_borders\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(designState.showBorders)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // 发送请求
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(APIError(message: "无效的响应", statusCode: nil))
            }

            guard 200...299 ~= httpResponse.statusCode else {
                // 尝试解析错误响应
                if let errorString = String(data: data, encoding: .utf8) {
                    return .failure(APIError(message: "后端错误(\(httpResponse.statusCode)): \(errorString)", statusCode: httpResponse.statusCode))
                }
                return .failure(APIError(message: "HTTP错误: \(httpResponse.statusCode)", statusCode: httpResponse.statusCode))
            }

            // 解析响应
            let decoder = JSONDecoder()
            let result = try decoder.decode(FinalGenerationResponse.self, from: data)

            // 下载PNG和PDF
            var pngImage: UIImage?
            var pdfData: Data?

            // 注意：result.png_url 和 result.pdf_url 已经包含/api前缀，所以需要使用baseURL的根地址
            let baseServerURL = baseURL.replacingOccurrences(of: "/api", with: "")

            let pngURL = URL(string: baseServerURL + result.png_url)
            if let pngURL = pngURL {
                let pngData = try await downloadImage(from: pngURL)
                pngImage = UIImage(data: pngData)
            }

            let pdfURL = URL(string: baseServerURL + result.pdf_url)
            if let pdfURL = pdfURL {
                let (data, _) = try await session.data(from: pdfURL)
                pdfData = data
            }

            let generationData = BookmarkGenerationData(image: pngImage, pdf: pdfData)
            return .success(generationData)

        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(APIError(message: "生成失败: \(error.localizedDescription)", statusCode: nil))
        }
    }

    /// 生成预览（调用后端预览API）
    func generatePreview(
        mood: String,
        complexity: Int,
        colors: [String],
        layout: String
    ) async -> Result<PreviewImage, APIError> {
        do {
            let request = [
                "mood": mood,
                "complexity": complexity,
                "colors": colors,
                "layout": layout
            ] as [String : Any]

            let response: PreviewResponse = try await performRequest(
                endpoint: "/generate-preview",
                method: .POST,
                body: request
            )

            // 下载预览图片
            // 注意：urlString 已经包含/api前缀，所以需要使用baseURL的根地址
            let baseServerURL = baseURL.replacingOccurrences(of: "/api", with: "")
            if let urlString = response.preview_url,
               let url = URL(string: baseServerURL + urlString) {
                let imageData = try await downloadImage(from: url)
                if let image = UIImage(data: imageData) {
                    return .success(PreviewImage(image: image, url: urlString))
                }
            }

            return .failure(APIError(message: "无法加载预览图片", statusCode: nil))
        } catch let error as APIError {
            // 直接抛出错误，不再使用mock
            return .failure(error)
        } catch {
            return .failure(APIError(message: "预览生成失败: \(error.localizedDescription)", statusCode: nil))
        }
    }

    /// 文生图（调用后端文生图API）
    func generateTextToImage(
        prompt: String,
        mood: String
    ) async -> Result<Data, APIError> {
        do {
            NSLog("🎨 [Network] generateTextToImage called")
            NSLog("   - prompt: \(prompt)")
            NSLog("   - mood: \(mood)")

            // 准备multipart/form-data请求
            guard let url = URL(string: baseURL + "/text-to-image") else {
                NSLog("❌ [Network] Invalid URL")
                return .failure(APIError(message: "无效的URL", statusCode: nil))
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            // 创建boundary
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // 构建multipart body
            var body = Data()

            // 添加prompt
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // 添加mood
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mood\"\r\n\r\n".data(using: .utf8)!)
            body.append(mood.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            // 添加size（书签竖版，使用GLM支持的尺寸）
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
            body.append("768x1344".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            NSLog("📤 [Network] Sending text-to-image request...")

            // 发送请求
            let (responseData, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ [Network] Invalid response type")
                return .failure(APIError(message: "无效的响应", statusCode: nil))
            }

            NSLog("📊 [Network] HTTP Status: \(httpResponse.statusCode)")
            guard 200...299 ~= httpResponse.statusCode else {
                if let errorString = String(data: responseData, encoding: .utf8) {
                    NSLog("❌ [Network] Error response: \(errorString)")
                    return .failure(APIError(message: "后端错误(\(httpResponse.statusCode)): \(errorString)", statusCode: httpResponse.statusCode))
                }
                return .failure(APIError(message: "HTTP错误: \(httpResponse.statusCode)", statusCode: httpResponse.statusCode))
            }

            // 解析响应
            NSLog("✅ [Network] Parsing text-to-image response...")
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let downloadURL = json["download_url"] as? String {
                NSLog("✅ [Network] Got download URL: \(downloadURL)")

                // 下载生成的图片
                // 注意：downloadURL已经包含/api前缀，所以需要使用baseURL的根地址
                let baseServerURL = baseURL.replacingOccurrences(of: "/api", with: "")
                let imageURL = URL(string: baseServerURL + downloadURL)
                if let imageURL = imageURL {
                    let imageData = try await downloadImage(from: imageURL)
                    NSLog("✅ [Network] Text-to-image image downloaded, size: \(imageData.count) bytes")
                    return .success(imageData)
                }
            }

            return .failure(APIError(message: "无法解析文生图响应", statusCode: nil))

        } catch let error as APIError {
            NSLog("❌ [Network] APIError: \(error.message)")
            return .failure(error)
        } catch {
            NSLog("❌ [Network] Exception: \(error.localizedDescription)")
            return .failure(APIError(message: "文生图失败: \(error.localizedDescription)", statusCode: nil))
        }
    }

    /// 生成背景图片（返回UIImage，用于在视图中显示）
    func generateBackgroundImage(
        prompt: String,
        mood: String
    ) async -> Result<UIImage, APIError> {
        NSLog("🎨 [Network] generateBackgroundImage called")
        NSLog("   - prompt: \(prompt)")
        NSLog("   - mood: \(mood)")

        // 调用文生图API获取图片数据
        let result = await generateTextToImage(prompt: prompt, mood: mood)

        switch result {
        case .success(let data):
            if let image = UIImage(data: data) {
                NSLog("✅ [Network] Background image created successfully")
                return .success(image)
            } else {
                NSLog("❌ [Network] Failed to create UIImage from data")
                return .failure(APIError(message: "无法创建图片", statusCode: nil))
            }
        case .failure(let error):
            NSLog("❌ [Network] generateBackgroundImage failed: \(error.message)")
            return .failure(error)
        }
    }

    // MARK: - Private Methods

    private enum HTTPMethod: String {
        case GET
        case POST
        case PUT
        case DELETE
    }

    private func performRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: U? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError(message: "无效的URL", statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try? encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "无效的响应", statusCode: nil)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // 尝试解析后端返回的详细错误信息
            var errorMessage = "HTTP错误: \(httpResponse.statusCode)"
            if let errorString = String(data: data, encoding: .utf8) {
                errorMessage += " - \(errorString)"
            }
            throw APIError(message: errorMessage, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(T.self, from: data)

        return result
    }

    // 支持字典类型的body
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError(message: "无效的URL", statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "无效的响应", statusCode: nil)
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // 尝试解析后端返回的详细错误信息
            var errorMessage = "HTTP错误: \(httpResponse.statusCode)"
            if let errorString = String(data: data, encoding: .utf8) {
                errorMessage += " - \(errorString)"
            }
            throw APIError(message: errorMessage, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(T.self, from: data)

        return result
    }

    // 下载图片
    private func downloadImage(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}

// MARK: - UIColor Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}

// MARK: - BookmarkGenerationData

struct BookmarkGenerationData {
    let image: UIImage?
    let pdf: Data?
}

// MARK: - PreviewImage

struct PreviewImage {
    let image: UIImage
    let url: String
}

// MARK: - PreviewResponse

struct PreviewResponse: Codable {
    let preview_url: String?
    let width: Int
    let height: Int
}

// MARK: - FinalGenerationResponse

struct FinalGenerationResponse: Codable {
    let png_url: String
    let pdf_url: String
    let width: Int
    let height: Int
    let dpi: Int
}

// MARK: - Backend Value Conversion Helpers

/// 将iOS的MoodOption转换为后端期望的中文枚举值
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

/// 将iOS的LayoutOption转换为后端期望的枚举值
private func layoutToBackendValue(_ layout: LayoutOption?) -> String {
    guard let layout = layout else {
        return "left-right"  // 默认值
    }

    switch layout.type {
    case .horizontal:
        return "left-right"
    case .vertical:
        return "top-bottom"
    case .centered:
        return "center-focused"
    case .mosaic:
        return "mosaic-grid"
    case .fullBleed:
        return "full-bleed-image"
    }
}

