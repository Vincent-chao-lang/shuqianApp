//
//  ChooseLayoutView.swift
//  BookmarkDesigner
//
//  步骤4: 选择布局方式
//  ⚠️ DEPRECATED: 此文件已废弃，新流程不再使用布局选择步骤
//

// 此文件已被禁用，因为新流程移除了布局选择步骤
// 上传的图片直接作为完整背景，无需选择布局

/*
import SwiftUI

struct ChooseLayoutView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var designState: DesignState
    @State private var showingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    // 进度指示器
                    ProgressBar(currentStep: 4, totalSteps: 5)

                    VStack(spacing: 24) {
                        // 标题
                        VStack(spacing: 8) {
                            Text("选择书签的布局方式")
                                .font(.system(size: 24, weight: .bold))
                            Text("决定图片和文字的排列方式")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)

                        // 布局选项卡片
                        VStack(spacing: 16) {
                            ForEach(designState.availableLayouts) { layout in
                                LayoutCard(
                                    layout: layout,
                                    isSelected: designState.selectedLayout?.id == layout.id
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        designState.selectedLayout = layout
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // 预览按钮
                        if let layout = designState.selectedLayout {
                            Button {
                                showingPreview = true
                            } label: {
                                HStack {
                                    Image(systemName: "eye")
                                    Text("查看大图预览")
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(hex: "#667eea"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "#667eea").opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }

            // 导航按钮 - 固定在底部
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // 上一步
                    Button {
                        path.removeLast()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("上一步")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 下一步
                    Button {
                        designState.goToNextStep()
                        // DEPRECATED: "content" destination no longer exists
                        // path.append(AppDestination.content.rawValue)
                    } label: {
                        Text("下一步")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(designState.selectedLayout == nil ? Color.gray : Color(hex: "#667eea"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(designState.selectedLayout == nil)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
            .background(Color(uiColor: .systemBackground))
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showingPreview) {
            if let layout = designState.selectedLayout {
                LayoutPreviewSheet(layout: layout)
            }
        }
    }
}

// MARK: - 布局预览Sheet

struct LayoutPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    let layout: LayoutOption

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // 布局预览
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .systemGray6))
                        .frame(width: 200, height: 320)

                    // 根据布局类型显示不同的预览
                    layoutPreview
                }

                VStack(spacing: 12) {
                    Text(layout.type.rawValue)
                        .font(.system(size: 24, weight: .bold))

                    Text(layout.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("布局预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var layoutPreview: some View {
        switch layout.type {
        case .horizontal:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 80, height: 200)

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 20)
                }
                .frame(width: 80)
            }

        case .vertical:
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 160, height: 150)

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 16)
                }
            }

        case .centered:
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 20)
                        .frame(width: 140)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 20)
                        .frame(width: 140)
                }
            }

        case .mosaic:
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 95, height: 95)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.5))
                        .frame(width: 95, height: 95)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 95, height: 95)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.opacity(0.5))
                        .frame(width: 95, height: 95)
                }
            }

        case .fullBleed:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.5))
                .frame(width: 160, height: 250)
                .overlay {
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.9))
                            .frame(height: 60)
                            .padding(.bottom, 20)
                    }
                }
        }
    }
}

struct ChooseLayoutView_Previews: PreviewProvider {
    static var previews: some View {
        @State var path: NavigationPath = .init()

        NavigationStack {
            ChooseLayoutView(path: $path)
                .environmentObject(DesignState())
        }
    }
}
*/
