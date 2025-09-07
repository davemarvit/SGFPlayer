// MARK: - File: SGFPlayerApp.swift
import SwiftUI

@main
struct SGFPlayerApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
        }
    }
}
