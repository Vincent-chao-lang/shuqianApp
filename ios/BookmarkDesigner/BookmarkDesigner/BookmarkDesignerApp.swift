//
//  BookmarkDesignerApp.swift
//  BookmarkDesigner
//
//  主应用入口文件
//

import SwiftUI

@main
struct BookmarkDesignerApp: App {
    @StateObject private var designState = DesignState()
    @StateObject private var networkManager = NetworkManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(designState)
                .environmentObject(networkManager)
        }
    }
}
