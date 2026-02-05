//
//  UIImageExtensions.swift
//  BookmarkDesigner
//
//  UIImage扩展，添加图片处理功能
//

import UIKit
import SwiftUI

extension UIImage {
    /// 调整图片大小
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 按比例缩放图片
    func scaledBy(_ factor: CGFloat) -> UIImage {
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        return resized(to: newSize)
    }

    /// 裁剪图片到指定区域
    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    /// 将图片转换为base64字符串
    func toBase64(compressionQuality: CGFloat = 1.0) -> String? {
        guard let imageData = jpegData(compressionQuality: compressionQuality) else { return nil }
        return imageData.base64EncodedString()
    }

    /// 从base64字符串创建图片
    static func from(base64 string: String) -> UIImage? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return UIImage(data: data)
    }

    /// 获取图片的宽高比
    var aspectRatio: CGFloat {
        return size.width / size.height
    }

    /// 将图片调整为最大尺寸，保持宽高比
    func aspectFitted(to maxSize: CGSize) -> UIImage {
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        if ratio >= 1 {
            return self
        }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return resized(to: newSize)
    }

    /// 将图片调整为最小尺寸，保持宽高比
    func aspectFilled(to size: CGSize) -> UIImage {
        let widthRatio = size.width / self.size.width
        let heightRatio = size.height / self.size.height
        let ratio = max(widthRatio, heightRatio)

        if ratio <= 1 {
            return self
        }

        let newSize = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        return resized(to: newSize)
    }
}

// MARK: - 使用示例

#Preview {
    VStack {
        Text("UIImage Extensions")
            .font(.headline)
        Text("See UIImageExtensions.swift for utility methods")
            .foregroundColor(.secondary)
    }
}
