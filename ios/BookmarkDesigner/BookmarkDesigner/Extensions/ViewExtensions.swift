//
//  ViewExtensions.swift
//  BookmarkDesigner
//
//  View扩展，添加常用修饰符
//

import SwiftUI

extension View {
    /// 隐藏键盘
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 条件性应用修饰符
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 条件性应用修饰符（带true/false两种情况）
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }

    /// 添加卡片样式
    func cardStyle() -> some View {
        self
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    /// 添加渐变背景
    func gradientBackground(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colors),
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Card Style")
            .padding()
            .cardStyle()

        Text("Gradient Background")
            .foregroundColor(.white)
            .padding()
            .gradientBackground(colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")])
    }
    .padding()
}
