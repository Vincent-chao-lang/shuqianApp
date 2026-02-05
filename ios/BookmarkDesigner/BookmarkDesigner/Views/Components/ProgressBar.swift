//
//  ProgressBar.swift
//  BookmarkDesigner
//
//  进度条组件，显示当前步骤
//

import SwiftUI

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 12) {
            // 进度条
            HStack(spacing: 0) {
                ForEach(1...totalSteps, id: \.self) { step in
                    if step < totalSteps {
                        StepIndicator(
                            step: step,
                            currentStep: currentStep,
                            showLine: true
                        )
                    } else {
                        StepIndicator(
                            step: step,
                            currentStep: currentStep,
                            showLine: false
                        )
                    }
                }
            }
            .frame(height: 40)

            // 步骤名称
            HStack {
                Text("步骤 \(currentStep)/\(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#667eea"))
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

struct StepIndicator: View {
    let step: Int
    let currentStep: Int
    let showLine: Bool

    var body: some View {
        ZStack {
            // 连接线
            if showLine {
                Rectangle()
                    .fill(step < currentStep ? Color(hex: "#667eea") : Color(uiColor: .systemGray5))
                    .frame(height: 3)
                    .padding(.leading, 20)
            }

            // 圆圈
            ZStack {
                Circle()
                    .fill(step <= currentStep ? Color(hex: "#667eea") : Color(uiColor: .systemGray5))
                    .frame(width: 30, height: 30)

                if step < currentStep {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(step <= currentStep ? .white : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @State var path: NavigationPath = .init()

    VStack(spacing: 20) {
        ProgressBar(currentStep: 1, totalSteps: 5)
        ProgressBar(currentStep: 2, totalSteps: 5)
        ProgressBar(currentStep: 3, totalSteps: 5)
        ProgressBar(currentStep: 4, totalSteps: 5)
        ProgressBar(currentStep: 5, totalSteps: 5)
    }
    .padding()
}
