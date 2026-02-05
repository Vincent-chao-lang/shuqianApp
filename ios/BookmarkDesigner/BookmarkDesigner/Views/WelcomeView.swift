//
//  WelcomeView.swift
//  BookmarkDesigner
//
//  欢迎页面，App的入口界面
//

import SwiftUI

struct WelcomeView: View {
    @Binding var path: NavigationPath
    @State private var showAnimation = false

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo/图标
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                        .scaleEffect(showAnimation ? 1.0 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showAnimation)

                    Text("书签设计工坊")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(showAnimation ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.2), value: showAnimation)

                    Text("AI文生图 + 个性化文字")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .opacity(showAnimation ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: showAnimation)
                }

                Spacer()

                // 功能介绍 - 更新为新的流程
                VStack(spacing: 20) {
                    FeatureRow(
                        icon: "photo.on.rectangle.angled",
                        title: "上传参考图",
                        description: "上传你喜欢的书签图片作为参考"
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: showAnimation)

                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "AI智能分析",
                        description: "分析书签图片并生成描述"
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.5), value: showAnimation)

                    FeatureRow(
                        icon: "paintbrush.fill",
                        title: "生成书签图案",
                        description: "文生图创建独特图案"
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.6), value: showAnimation)

                    FeatureRow(
                        icon: "text.alignleft",
                        title: "添加文字",
                        description: "自定义样式和精确位置"
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.7), value: showAnimation)

                    FeatureRow(
                        icon: "square.and.arrow.down",
                        title: "导出书签",
                        description: "高清PDF和图片格式"
                    )
                    .opacity(showAnimation ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6).delay(0.8), value: showAnimation)
                }
                .padding(.horizontal, 32)

                Spacer()

                // 开始按钮
                Button {
                    path.append(AppDestination.upload.rawValue)
                } label: {
                    HStack(spacing: 8) {
                        Text("开始设计")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#667eea"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                }
                .padding(.horizontal, 32)
                .opacity(showAnimation ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).delay(0.9), value: showAnimation)

                Spacer().frame(height: 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            showAnimation = true
        }
    }
}

// MARK: - 功能介绍行组件

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()
        }
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    NavigationStack {
        WelcomeView(path: $path)
            .environmentObject(DesignState())
    }
}
