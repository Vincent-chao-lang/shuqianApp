//
//  ColorExtensions.swift
//  BookmarkDesigner
//
//  Color扩展，支持从十六进制字符串创建颜色
//

import SwiftUI

extension Color {
    /// 从十六进制字符串创建Color
    /// - Parameter hex: 十六进制颜色字符串，格式如 "#FF5733" 或 "FF5733"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1.0
        )
    }

    /// 将Color转换为十六进制字符串
    func toHex() -> String? {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
        #else
        return nil
        #endif
    }
}

#Preview {
    VStack(spacing: 10) {
        Color(hex: "#667eea")
            .frame(height: 50)
        Color(hex: "#764ba2")
            .frame(height: 50)
        Color(hex: "#FF5733")
            .frame(height: 50)
    }
}
