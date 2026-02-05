//
//  LayoutCard.swift
//  BookmarkDesigner
//
//  布局选项卡片组件
//

import SwiftUI

struct LayoutCard: View {
    let layout: LayoutOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 布局预览图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemGray6))
                        .frame(width: 80, height: 120)

                    Image(systemName: layout.type.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(isSelected ? Color(hex: "#667eea") : .secondary)
                }

                // 布局信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(layout.type.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(layout.description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("已选择")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "#667eea"))
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "#667eea") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    VStack(spacing: 16) {
        LayoutCard(
            layout: LayoutOption.exampleLayouts[0],
            isSelected: true
        ) { }

        LayoutCard(
            layout: LayoutOption.exampleLayouts[1],
            isSelected: false
        ) { }

        LayoutCard(
            layout: LayoutOption.exampleLayouts[2],
            isSelected: false
        ) { }
    }
    .padding()
}
