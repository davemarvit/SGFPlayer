import Foundation

struct DebugConfig {
    static let enableVerboseLogging = false
    static let enablePhysicsDebugging = false
    static let enableUIDebugging = false
    static let enableGameplayDebugging = false

    static func configureLogging() {
        if enableVerboseLogging {
            Logger.enableDebugLogging()
        } else {
            Logger.setLogLevel(.warning, .error, .critical) // Include warnings to see UI updates
        }
    }
}