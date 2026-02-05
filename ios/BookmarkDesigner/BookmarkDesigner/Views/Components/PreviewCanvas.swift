//
//  PreviewCanvas.swift
//  BookmarkDesigner
//
//  实时预览画布组件
//

import SwiftUI

struct PreviewCanvas: View {
    @ObservedObject var designState: DesignState

    var body: some View {
        VStack(spacing: 0) {
            // 书签预览
            ZStack {
                // 背景渐变
                if let scheme = designState.selectedColorScheme, let bgColor = scheme.colors.first(where: { $0.role == .background }) {
                    Color(hex: bgColor.hex)
                } else {
                    Color(uiColor: .systemGray6)
                }

                VStack(spacing: 0) {
                    // 图片区域
                    if !designState.userPhotos.isEmpty {
                        Image(uiImage: designState.userPhotos[0])
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    } else {
                        // 占位符
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 120)
                            .overlay {
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                    Text("图片区域")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }

                    // 文字区域
                    VStack(spacing: 8) {
                        if designState.userText.isEmpty {
                            Text("这里将显示你的文字")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(height: 40)
                        } else {
                            Text(designState.userText)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .frame(height: 60, alignment: .topLeading)
                                .padding(8)
                                .background(Color.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        // 装饰元素
                        HStack(spacing: 8) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(designState.selectedColorScheme?.colors.last.map { Color(hex: $0.hex) } ?? Color.gray.opacity(0.5))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .frame(width: 150, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            // 尺寸标注
            Text("书签尺寸: 5cm × 15cm")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    PreviewCanvas(designState: DesignState())
        .padding()
}
