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

// MARK: - SGF and Game Types - Screensaver Simplified Versions

struct SGFGameTree {
    let moves: [(Stone, (Int, Int)?)]
}

extension SGFGame {
    static func from(tree: SGFGameTree) -> SGFGame {
        var game = SGFGame()
        game.boardSize = 19
        game.moves = tree.moves
        game.setup = []
        return game
    }
}

extension SGFParser {
    static func parseToGameTree(text: String) throws -> SGFGameTree {
        // Use the real SGF parser but extract just the moves
        let realTree = try SGFParser.parse(text: text)

        var moves: [(Stone, (Int, Int)?)] = []

        for node in realTree.nodes {
            // Check for black moves
            if let blackMoves = node.props["B"] {
                for move in blackMoves {
                    if move.isEmpty {
                        moves.append((.black, nil)) // Pass
                    } else if move.count == 2 {
                        let chars = Array(move)
                        let x = Int(chars[0].asciiValue! - 97) // 'a' = 0
                        let y = Int(chars[1].asciiValue! - 97)
                        moves.append((.black, (x, y)))
                    }
                }
            }

            // Check for white moves
            if let whiteMoves = node.props["W"] {
                for move in whiteMoves {
                    if move.isEmpty {
                        moves.append((.white, nil)) // Pass
                    } else if move.count == 2 {
                        let chars = Array(move)
                        let x = Int(chars[0].asciiValue! - 97) // 'a' = 0
                        let y = Int(chars[1].asciiValue! - 97)
                        moves.append((.white, (x, y)))
                    }
                }
            }
        }

        return SGFGameTree(moves: moves)
    }
}