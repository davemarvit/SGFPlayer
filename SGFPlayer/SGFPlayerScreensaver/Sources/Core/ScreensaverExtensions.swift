// MARK: - Screensaver Extensions
// Essential extensions and compatibility shims for screensaver environment

import Foundation
import Cocoa

// MARK: - ObservableObject Compatibility

// Simple ObservableObject protocol for screensaver (no Combine dependency)
protocol ObservableObject: AnyObject {
    // Marker protocol - in screensaver we don't need reactive updates
}

// MARK: - Stone and Game Types

enum Stone: Equatable, Hashable {
    case black
    case white
}

struct BoardSnapshot {
    let size: Int
    let grid: [[Stone?]]
}

// MARK: - Physics Support Types
// Note: StonePosition, BowlPhysicsResult, and MoveRef are defined in other files

// MARK: - Game Wrapper

struct SGFGameWrapper: Identifiable {
    let id = UUID()
    let url: URL
    let game: SGFGame

    var fingerprint: String {
        return url.lastPathComponent + "_" + String(url.path.hashValue)
    }
}

// MARK: - Extensions for Core Graphics

extension NSColor {
    static var systemBackground: NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlBackgroundColor
        } else {
            return NSColor.windowBackgroundColor
        }
    }
}

// MARK: - SGF and Game Types
// Note: SGFParser, SGFGame, and SGFPlayer are defined in other files