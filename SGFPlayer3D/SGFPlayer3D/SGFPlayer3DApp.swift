// MARK: - File: SGFPlayer3DApp.swift
import SwiftUI

@main
struct SGFPlayer3DApp: App {
    @StateObject private var app = AppModel()

    init() {
        let logPath = NSHomeDirectory() + "/Desktop/sgfplayer3d_debug.txt"
        let msg = "DEBUG3D: App init starting\n"
        try? msg.appendToFile(at: logPath)
        NSLog("DEBUG3D: App init starting")
        DebugConfig.configureLogging()
        let msg2 = "DEBUG3D: App init complete\n"
        try? msg2.appendToFile(at: logPath)
        NSLog("DEBUG3D: App init complete")
    }

    var body: some Scene {
        let msg = "DEBUG3D: App body creating WindowGroup\n"
        try? msg.appendToFile(at: "/tmp/sgfplayer3d_debug.log")
        print(msg)
        return WindowGroup {
            ContentView3D()
                .environmentObject(app)
        }
    }
}
