// MARK: - File: SGFPlayerApp.swift
import SwiftUI

@main
struct SGFPlayerApp: App {
    @StateObject private var app = AppModel()

    init() {
        DebugConfig.configureLogging()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
        }
    }
}
