//
//  ColorSchemeCard.swift
//  BookmarkDesigner
//
//  配色方案卡片组件
//

import SwiftUI

struct ColorSchemeCard: View {
    let scheme: ColorScheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                colorBar
                colorInfo
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "#667eea") : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    checkmarkBadge
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 颜色条 - 手动展开避免 ForEach
    private var colorBar: some View {
        HStack(spacing: 0) {
            if scheme.colors.count > 0 {
                Color(hex: scheme.colors[0].hex)
                    .frame(maxWidth: .infinity)
            }
            if scheme.colors.count > 1 {
                Color(hex: scheme.colors[1].hex)
                    .frame(maxWidth: .infinity)
            }
            if scheme.colors.count > 2 {
                Color(hex: scheme.colors[2].hex)
                    .frame(maxWidth: .infinity)
            }
            if scheme.colors.count > 3 {
                Color(hex: scheme.colors[3].hex)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 配色信息 - 手动展开避免 ForEach
    private var colorInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scheme.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            // 颜色详情列表
            VStack(alignment: .leading, spacing: 6) {
                if scheme.colors.count > 0 {
                    colorRow(scheme.colors[0])
                }
                if scheme.colors.count > 1 {
                    colorRow(scheme.colors[1])
                }
                if scheme.colors.count > 2 {
                    colorRow(scheme.colors[2])
                }
                if scheme.colors.count > 3 {
                    colorRow(scheme.colors[3])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // 单个颜色行
    private func colorRow(_ color: DesignColor) -> some View {
        HStack(spacing: 8) {
            Color(hex: color.hex)
                .frame(width: 20, height: 20)
                .clipShape(Circle())

            Text(color.hex)
                .font(.system(size: 12))
                .monospaced()
                .foregroundStyle(.secondary)

            Text(color.name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var checkmarkBadge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#667eea"))
                .frame(width: 28, height: 28)

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(8)
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    VStack(spacing: 16) {
        ColorSchemeCard(
            scheme: ColorScheme.exampleSchemes[0],
            isSelected: true
        ) { }

        ColorSchemeCard(
            scheme: ColorScheme.exampleSchemes[1],
            isSelected: false
        ) { }

        ColorSchemeCard(
            scheme: ColorScheme.exampleSchemes[2],
            isSelected: false
        ) { }
    }
    .padding()
}
