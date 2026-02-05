//
//  ContentView.swift
//  BookmarkDesigner
//
//  主视图，管理应用的导航流程
//

import SwiftUI
import os.log

struct ContentView: View {
    @EnvironmentObject var designState: DesignState
    @EnvironmentObject var networkManager: NetworkManager
    @State var path: NavigationPath = .init()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(path: $path)
                .navigationDestination(for: String.self) { destination in
                    destinationView(for: destination)
                }
                .onAppear {
                    NSLog("✅ [ContentView] App started, NetworkManager available")
                }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: String) -> some View {
        switch destination {
        case "upload":
            UploadReferenceView(path: $path)
        case "ai-result":
            AIAnalysisResultView(path: $path)
        case "manual-config":
            ManualConfigView(path: $path)
        case "result":
            ResultView(path: $path)
        default:
            WelcomeView(path: $path)
        }
    }
}

enum AppDestination: String {
    case upload = "upload"
    case aiResult = "ai-result"
    case manualConfig = "manual-config"
    case result = "result"
}
