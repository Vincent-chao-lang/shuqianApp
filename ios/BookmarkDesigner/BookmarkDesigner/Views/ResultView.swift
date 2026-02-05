//
//  ResultView.swift
//  BookmarkDesigner
//
//  完成页面，展示最终生成的书签
//

import SwiftUI
import Photos

struct ResultView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var designState: DesignState
    @State private var showingShareSheet = false
    @State private var shareItems: [Any]?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var saveAlertTitle = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 成功标志
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(Color.green)
                    }

                    Text("书签生成完成！")
                        .font(.system(size: 24, weight: .bold))
                }
                .padding(.top, 40)

                // 书签预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("你的专属书签")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 24)

                    if let image = designState.finalBookmarkImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            .padding(.horizontal, 24)
                    }
                }

                // 设计参数摘要
                VStack(alignment: .leading, spacing: 12) {
                    Text("设计参数")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        if let mood = designState.selectedMood {
                            ParameterRow(icon: "sparkles", label: "氛围", value: mood.rawValue)
                        }

                        ParameterRow(icon: "slider.horizontal.3", label: "复杂度", value: designState.complexityDescription)

                        ParameterRow(icon: "person.text.rectangle", label: "正式度", value: designState.formalityDescription)

                        if let scheme = designState.selectedColorScheme {
                            ParameterRow(icon: "paintpalette", label: "配色", value: scheme.name)
                        }

                        if let layout = designState.selectedLayout {
                            ParameterRow(icon: "rectangle.3.group", label: "布局", value: layout.type.rawValue)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                // 下载和分享按钮
                VStack(spacing: 12) {
                    // 下载PNG
                    Button {
                        guard let image = designState.finalBookmarkImage else {
                            saveAlertTitle = "无法保存"
                            saveAlertMessage = "书签图片未生成，请重新生成"
                            showingSaveAlert = true
                            return
                        }
                        saveImageToPhotos(image)
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存PNG到相册")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "#667eea"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)

                    // 下载PDF
                    if let pdfData = designState.finalBookmarkPDF {
                        Button {
                            sharePDF(pdfData)
                        } label: {
                            HStack {
                                Image(systemName: "doc.richtext")
                                Text("分享PDF文件")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#764ba2"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 24)
                    }

                    // 分享按钮
                    Button {
                        prepareShareSheet()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享书签")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#667eea"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "#667eea").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                }

                // 重新设计按钮
                Button {
                    designState.reset()
                    path = NavigationPath()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重新设计")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            // 调试：检查数据状态
            print("📊 [ResultView] onAppear - Checking data:")
            print("   - finalBookmarkImage: \(designState.finalBookmarkImage != nil ? "✅ exists" : "❌ nil")")
            print("   - finalBookmarkPDF: \(designState.finalBookmarkPDF != nil ? "✅ exists (\(designState.finalBookmarkPDF!.count) bytes)" : "❌ nil")")
        }
        .alert(saveAlertTitle, isPresented: $showingSaveAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(saveAlertMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let items = shareItems {
                ShareSheet(activityItems: items)
            }
        }
    }

    // MARK: - Helper Methods

    private func saveImageToPhotos(_ image: UIImage) {
        // 检查相册访问权限
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            // 已授权，直接保存
            performSaveImage(image)
        case .denied, .restricted:
            // 权限被拒绝或受限
            saveAlertTitle = "无法保存"
            saveAlertMessage = "请在设置中允许访问相册权限"
            showingSaveAlert = true
        case .notDetermined:
            // 未请求权限，请求授权
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSaveImage(image)
                    } else {
                        self.saveAlertTitle = "无法保存"
                        self.saveAlertMessage = "需要相册权限才能保存书签图片"
                        self.showingSaveAlert = true
                    }
                }
            }
        @unknown default:
            saveAlertTitle = "错误"
            saveAlertMessage = "无法确定相册权限状态"
            showingSaveAlert = true
        }
    }

    private func performSaveImage(_ image: UIImage) {
        // 使用PHPhotoChangeRequest保存图片
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.saveAlertTitle = "保存成功"
                    self.saveAlertMessage = "书签已保存到相册"
                    print("✅ [ResultView] Image saved to photos successfully")
                } else {
                    self.saveAlertTitle = "保存失败"
                    if let error = error {
                        self.saveAlertMessage = "保存失败: \(error.localizedDescription)"
                        print("❌ [ResultView] Failed to save image: \(error.localizedDescription)")
                    } else {
                        self.saveAlertMessage = "保存失败，请重试"
                    }
                }
                self.showingSaveAlert = true
            }
        }
    }

    private func sharePDF(_ pdfData: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bookmark_\(UUID().uuidString).pdf")

        do {
            try pdfData.write(to: tempURL)
            shareItems = [tempURL]
            showingShareSheet = true
            print("✅ [ResultView] PDF prepared for sharing")
        } catch {
            saveAlertTitle = "分享失败"
            saveAlertMessage = "无法准备PDF文件: \(error.localizedDescription)"
            showingSaveAlert = true
            print("❌ [ResultView] Failed to save PDF: \(error)")
        }
    }

    private func prepareShareSheet() {
        var items: [Any] = []

        // 添加PNG图片
        if let image = designState.finalBookmarkImage {
            items.append(image)
            print("✅ [ResultView] Image added to share sheet")
        }

        // 添加PDF文件
        if let pdfData = designState.finalBookmarkPDF {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bookmark_\(UUID().uuidString).pdf")
            do {
                try pdfData.write(to: tempURL)
                items.append(tempURL)
                print("✅ [ResultView] PDF added to share sheet")
            } catch {
                print("⚠️ [ResultView] Failed to add PDF to share sheet: \(error)")
            }
        }

        if !items.isEmpty {
            shareItems = items
            showingShareSheet = true
        } else {
            saveAlertTitle = "分享失败"
            saveAlertMessage = "没有可分享的内容"
            showingSaveAlert = true
        }
    }
}

// MARK: - 参数行组件

struct ParameterRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#667eea"))
                .frame(width: 30)

            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    NavigationStack {
        ResultView(path: $path)
            .environmentObject(DesignState())
    }
}
