//
//  UploadReferenceView.swift
//  BookmarkDesigner
//
//  步骤1: 上传背景图片
//

import SwiftUI
import os.log

struct UploadReferenceView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var designState: DesignState
    @EnvironmentObject var networkManager: NetworkManager

    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isAnalyzing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 进度指示器
                ProgressBar(currentStep: 1, totalSteps: 2)

                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 12) {
                        Text("上传图片")
                            .font(.system(size: 28, weight: .bold))
                        Text("这张图片将作为书签参考图或背景")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text("支持JPG、PNG格式，建议尺寸 500×1500 像素")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    // 图片选择区域
                    VStack(spacing: 16) {
                        if designState.referenceImages.isEmpty {
                            // 空状态
                            VStack(spacing: 20) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 70))
                                    .foregroundStyle(Color(hex: "#667eea").opacity(0.6))

                                Text("点击下方按钮上传图片")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 250)
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            // 已选图片预览（只显示1张）
                            VStack(spacing: 12) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: designState.referenceImages[0])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.1), radius: 5)

                                    // 删除按钮
                                    Button {
                                        designState.referenceImages.removeAll()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                    }
                                    .padding(12)
                                }

                                Text("已选择背景图片")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // 操作按钮
                    HStack(spacing: 16) {
                        // 相册选择
                        Button {
                            showingPhotoLibrary = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("相册")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // 相机
                        Button {
                            showingCamera = true
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                Text("相机")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 选项按钮区域（只有在有图片时才显示）
                if !designState.referenceImages.isEmpty {
                    VStack(spacing: 16) {
                        Text("选择下一步操作方式")
                            .font(.system(size: 18, weight: .semibold))

                        // 选项A: AI智能解析
                        Button {
                            Task {
                                await analyzeWithAI()
                            }
                        } label: {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 20))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI智能解析")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("让AI自动分析并提取配色方案")
                                            .font(.system(size: 13))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .frame(height: 70)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "#667eea").opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(isAnalyzing)

                        // 选项B: 手动配置
                        Button {
                            designState.goToNextStep()
                            path.append("manual-config")
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("手动配置")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("手动选择配色方案并生成")
                                        .font(.system(size: 13))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .frame(height: 70)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 20)
            }
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let image = image {
                    designState.referenceImages = [image]  // 只保存1张
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let image = image {
                    designState.referenceImages = [image]  // 只保存1张
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            NSLog("✅ [UploadReferenceView] View appeared")
        }
    }

    // MARK: - Helper Methods

    private func analyzeWithAI() async {
        NSLog("🔍 [UploadReferenceView] analyzeWithAI() called")

        isAnalyzing = true
        designState.isAnalyzing = true
        designState.analysisError = nil

        NSLog("📡 [UploadReferenceView] Calling networkManager.analyzeImages...")
        let result = await networkManager.analyzeImages(designState.referenceImages)
        NSLog("📥 [UploadReferenceView] Got result from networkManager")

        await MainActor.run {
            isAnalyzing = false
            designState.isAnalyzing = false

            switch result {
            case .success(let analysis):
                designState.analysisResult = analysis
                // 从AI分析结果中提取配色方案
                if let colorScheme = designState.createColorSchemeFromAnalysis(analysis) {
                    designState.selectedColorScheme = colorScheme
                }
                // 跳转到AI解析结果页面
                path.append("ai-result")

            case .failure(let error):
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    NavigationStack {
        UploadReferenceView(path: $path)
            .environmentObject(DesignState())
            .environmentObject(NetworkManager())
    }
}
