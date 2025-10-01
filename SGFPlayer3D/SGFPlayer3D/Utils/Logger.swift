import Foundation
import os.log

enum LogLevel: String, CaseIterable {
    case debug = "🔍"
    case info = "ℹ️"
    case warning = "⚠️"
    case error = "❌"
    case critical = "🚨"
}

struct Logger {
    static var enabledLevels: Set<LogLevel> = [.error, .critical, .warning]

    static func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard enabledLevels.contains(level) else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "\(level.rawValue) [\(fileName):\(line)] \(message)"

        print(formattedMessage)
    }

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    static func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message, file: file, function: function, line: line)
    }

    static func setLogLevel(_ levels: LogLevel...) {
        enabledLevels = Set(levels)
    }

    static func enableDebugLogging() {
        enabledLevels = Set(LogLevel.allCases)
    }

    static func disableAllLogging() {
        enabledLevels = []
    }
}